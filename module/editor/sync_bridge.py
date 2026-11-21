"""Separate sync bridge; the existing Link Audio bridge remains untouched."""
import json
from PySide2.QtCore import QObject,Property,Signal,Slot,QProcess,QTimer
import math
from .local_control_407 import control_process
from pathlib import Path
SPEC=json.loads((Path(__file__).parent / 'link-ports.json').read_text())['sync']['ports']

class Editor(QObject):
 changed=Signal()
 def __init__(self,hub,identifier,kind):
  super().__init__(hub);self.hub=hub;self.identifier=identifier;self.record=hub.effects.get(identifier)
  hub.changed.connect(self.changed)
 def alive(self):
  return self.record is not None and self.hub.effects.get(self.identifier) is self.record and not self.hub.loading.value
 @Slot(str,str,float)
 def change(self,kind,symbol,value):
  if not self.alive() or kind!='sync' or not math.isfinite(value):return
  spec=next((p for p in SPEC if p['symbol']==symbol and p['type']=='Control' and p['direction']=='input'),None)
  if spec is None or not spec['minimum']<=value<=spec['maximum']:return
  if symbol=='clock_width_ms' and value not in (1,5,10):return
  self.hub.knobs.ui_knob_change(self.identifier,symbol,float(value))
  if symbol=='tempo_request' and value:
   QTimer.singleShot(30,lambda:self.hub.release_request(self.identifier,self.record,symbol,0))
  self.hub.changed.emit()
 @Slot(bool)
 def transport(self,play):
  if not self.alive():return
  self.change('sync','transport',1 if play else 0)
  QTimer.singleShot(30,lambda:self.hub.release_request(self.identifier,self.record,'transport',-1))
 status=Property('QVariantMap',lambda self:self.hub.status_data(),notify=changed)
 error=Property(str,lambda self:self.hub.problem,notify=changed)


class SyncEditor(Editor):
 @Slot(str)
 def selectConnection(self,value):
  if self.alive() and value in ['ethernet','wifi']:self.hub.call(dict(action='set',connection=value))
 @Slot()
 def retryConnection(self):
  if self.alive():self.hub.call(dict(action='retry'))
 @property
 def identifier_value(self):return self.identifier

class SyncHub(QObject):
 changed=Signal()
 def __init__(self,original,client='/usr/local/lib/hector-link-sync/client.py'):
  super().__init__();self.client=client;self.pending=None
  self.effects,self.knobs,self.loading=original.effects,original.knobs,original.loading
  self.load_seen=False
  original.changed.connect(self.original_changed)
  self.data={};self.streams=[];self.editors={};self.retired=[];self.problem='';self.request=None
  self.process=control_process(self,self.client);self.process.started.connect(self.send)
  self.process.finished.connect(self.complete);self.process.errorOccurred.connect(self.failed)
  self.timeout=QTimer(self);self.timeout.setSingleShot(True);self.timeout.timeout.connect(self.process.kill)
  self.timer=QTimer(self);self.timer.setInterval(400);self.timer.timeout.connect(self.poll);self.timer.start()
 def original_changed(self):
  if self.loading.value and not self.load_seen:self.begin_load()
  self.load_seen=bool(self.loading.value)
  self.changed.emit()
 def identifier(self,kind):
  found=[i for i,r in self.effects.items() if kind=='sync' and r.get('effect_type')=='ableton_link']
  return found[0] if len(found)==1 else None
 def release_request(self,identifier,record,symbol,value):
  if not self.loading.value and self.effects.get(identifier) is record:self.knobs.ui_knob_change(identifier,symbol,float(value))
 @Slot(str,result=bool)
 def exists(self,effect_type):return any(r.get('effect_type')==effect_type for r in self.effects.values())
 def begin_load(self):
  self.pending=None;self.request=None;self.data={};self.problem=''
  for editor in self.editors.values():self.retired.append(editor)
  self.editors.clear()
  if self.process.state()!=QProcess.NotRunning:self.process.kill()
  self.changed.emit()
 def fail(self,message):self.problem=message;self.changed.emit()
 @Slot(str,result=QObject)
 def bridge(self,identifier):
  old=self.editors.get(identifier);record=self.effects.get(identifier)
  if old is None or old.record is not record:
   if old:self.retired.append(old)
   old=SyncEditor(self,identifier,'sync');self.editors[identifier]=old
  return old
 def call(self,request):
  if self.process.state()!=QProcess.NotRunning:
   if request.get('action') in ['set','retry']:self.pending=request
   return
  self.request=request;self.process.start('/usr/bin/python3',['-I','-B',self.client]);self.timeout.start(6000)
 def send(self):self.process.write(json.dumps(self.request).encode()+b'\n');self.process.closeWriteChannel()
 def poll(self):
  if self.loading.value or self.identifier('sync') is None:return
  self.call({'action':'status'})
 def failed(self,error):
  if error==QProcess.FailedToStart:self.complete(-1,QProcess.NormalExit)
 def unavailable(self,message):
  # Keep connection preference and last known tempo, but never present a failed
  # observation as live peers/playback/readiness. This changes display state
  # only; it sends no transport, enable, service restart or network command.
  previous=self.data if isinstance(self.data,dict) else {}
  session=previous.get('session',{})
  session={key:session[key] for key in ('bpm','quantum') if key in session}
  session.update(online=False,playing=False,running=False,peers=0)
  self.data=dict(selected=previous.get('selected','wifi'),active='',ip='',ready=False,
                 online=False,busy=False,attempts=4,status='Link status unavailable',
                 session=session)
  self.problem=message if isinstance(message,str) and message else 'Link connection control unavailable'
 @staticmethod
 def valid_data(data):
  if not isinstance(data,dict):return False
  session=data.get('session',{})
  if not isinstance(session,dict) or not isinstance(data.get('connections',{}),dict):return False
  for key in ('ready','online','busy','sync_attached','sync_processing'):
   if key in data and not isinstance(data[key],bool):return False
  for key in ('selected','active','ip','status','error'):
   if key in data and not isinstance(data[key],str):return False
  if 'attempts' in data and (not isinstance(data['attempts'],(int,float)) or not math.isfinite(data['attempts']) or data['attempts']<0):return False
  for key in ('online','playing','running'):
   if key in session and not isinstance(session[key],bool):return False
  for key in ('bpm','beat','quantum','peers'):
   if key in session:
    value=session[key]
    if not isinstance(value,(int,float)) or not math.isfinite(value):return False
    if key in ('bpm','quantum') and value<=0:return False
    if key=='peers' and value<0:return False
  return True
 def complete(self,code,_):
  if self.request is None:return
  self.timeout.stop();request,self.request=self.request,None
  raw=bytes(self.process.readAllStandardOutput());self.process.readAllStandardError()
  try:
   value=json.loads(raw) if code==0 and len(raw)<65536 else {}
   if not isinstance(value,dict):raise ValueError('Invalid control response')
   if value.get('ok') is True and self.valid_data(value.get('data')):
    self.data=value['data'];self.problem=self.data.get('error','')
   else:self.unavailable(value.get('error','Link connection control unavailable'))
  except (ValueError,KeyError,TypeError,OverflowError):self.unavailable('Link connection control unavailable')
  self.changed.emit()
  if self.pending is not None:
   pending,self.pending=self.pending,None;self.call(pending)
 def status_data(self):
  record=self.effects.get(self.identifier('sync'),{})
  controls={k:float(v.value) for k,v in record.get('controls',{}).items()}
  s=dict(self.data.get('session',{}));q=max(1,s.get('quantum',4))
  s.update(enabled=controls.get('enabled',0),startStop=controls.get('start_stop_sync',0),launchQuantum=controls.get('quantum',4),
           ppq=controls.get('ppq',1),clockWidthMs=controls.get('clock_width_ms',1),offsetMs=controls.get('offset_ms',0),phase=(s.get('beat',0)/q)%1,connection=self.data.get('selected','wifi'),
           activeConnection=self.data.get('active',''),connectionStatus=self.data.get('status','Checking…'),ip=self.data.get('ip',''),
           connections=self.data.get('connections',{}),busy=self.data.get('busy',False),
           ready=self.data.get('ready',False),syncAttached=self.data.get('sync_attached',False),
           syncProcessing=self.data.get('sync_processing',False),
           canRetry=self.data.get('attempts',0)>=4 and not self.data.get('online',False))
  s.setdefault('online',False);s.setdefault('bpm',120);s.setdefault('peers',0)
  return s
 def close(self):
  self.timer.stop();self.timeout.stop();self.pending=None
  if self.process.state()!=QProcess.NotRunning:self.process.kill();self.process.waitForFinished(1000)
