import contextlib,os,stat,signal,time,re
from pathlib import Path

class Log:
    """Try independent sinks; report loss without interrupting transaction recovery."""
    def __init__(self, paths):
        self.streams=[];self.errors=[];self.warned=False
        for candidate in paths:
            try:
                path=candidate() if callable(candidate) else candidate
                fd=os.open(str(path),os.O_WRONLY|os.O_CREAT|os.O_APPEND|os.O_NOFOLLOW,0o600)
                info=os.fstat(fd)
                if not stat.S_ISREG(info.st_mode) or info.st_nlink!=1:
                    os.close(fd);raise ValueError('Unsafe installation log')
                self.streams.append(os.fdopen(fd,'w',buffering=1))
            except (OSError,ValueError) as error:self.errors.append(str(error))
        self.require_durable()
        if self.errors:self.write('Installation log sink unavailable: '+'; '.join(self.errors)+'\n')
    def require_durable(self):
        if not self.streams:raise ValueError('Cannot retain an installation log: '+'; '.join(self.errors))
    def failed(self,stream,error):
        self.errors.append(str(error));self.streams.remove(stream)
        try:stream.close()
        except OSError:pass
        if not self.streams and not self.warned:
            self.warned=True
            # fd2 is the original systemd console/journal, not this Python object.
            # Never turn a logging failure into an exception during rollback.
            try:os.write(2,('DURABLE INSTALLATION LOG LOST; transaction recovery continues: '+str(error)+'\n').encode())
            except OSError:pass
    def write(self,text):
        for stream in tuple(self.streams):
            try:stream.write(text);stream.flush();os.fsync(stream.fileno())
            except OSError as error:self.failed(stream,error)
        return len(text) if self.streams else 0
    def flush(self):
        for stream in tuple(self.streams):
            try:stream.flush();os.fsync(stream.fileno())
            except OSError as error:self.failed(stream,error)


def emit(stage):
    print(time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())+
          '  [boot +%.3fs] '%time.monotonic()+stage,flush=True)


def startup_log(service):
    """Retain the entry phase on protected SD even if USB disappears."""
    parent=Path('/mnt/community-lab')
    service.engine.Device.protected(parent.parent)
    parent.mkdir(mode=0o700,exist_ok=True)
    service.engine.Device.protected(parent)
    root=parent/'poly-view-usb-startup'
    root.mkdir(mode=0o700,exist_ok=True)
    service.engine.Device.protected(root)
    boot=Path('/proc/sys/kernel/random/boot_id').read_text().strip()
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}',boot):raise ValueError('Invalid boot identifier')
    return root/('entry-'+boot+'-'+str(os.getpid())+'.log')


@contextlib.contextmanager
def verification_budget(seconds=90):
    def expired(signum,frame):
        raise TimeoutError('USB verification exceeded90seconds. No app files changed; inspect the saved startup log.')
    previous=signal.signal(signal.SIGALRM,expired)
    old_timer=signal.alarm(seconds)
    try:yield
    finally:
        signal.alarm(0);signal.signal(signal.SIGALRM,previous)
        if old_timer:signal.alarm(old_timer)


