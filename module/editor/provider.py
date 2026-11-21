"""Mandatory provider admission; installation remains independent and offline."""
import os
import stat

PATHS=('/usr/local/lib/hector-network-panel/backend.py',
       '/etc/systemd/system/hector-network-panel.service')

def installed():
    for name in PATHS:
        fd=None
        try:
            fd=os.open(name,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK|os.O_CLOEXEC)
            info=os.fstat(fd);current=os.lstat(name)
            if (not stat.S_ISREG(info.st_mode) or info.st_uid!=0 or info.st_mode&0o022
                    or not 0<info.st_size<2*1024*1024 or (info.st_dev,info.st_ino)!=(current.st_dev,current.st_ino)):
                return False
        except OSError:return False
        finally:
            if fd is not None:os.close(fd)
    return True
