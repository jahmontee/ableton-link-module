"""Portable host adapter for the unchanged Link Sync bridge and editor."""
import json
from pathlib import Path
from PySide2.QtCore import QObject, Property, Signal, Slot
from .sync_bridge import SyncHub
from .provider import installed as network_installed


class Original(QObject):
    changed = Signal()

    def __init__(self, api):
        super().__init__()
        self.effects, self.knobs = api['effects'], api['knobs']
        self.loading = api['loading']
        if self.loading is None:
            raise ValueError('Link requires the host patch-load guard')


class Backend(QObject):
    changed = Signal()

    def __init__(self, effect, api):
        super().__init__()
        self.module_version = json.loads((Path(__file__).resolve().parent.parent / "module.json").read_bytes())["version"]
        self.effect, self.api = effect, api
        self.original = Original(api)
        self.original.setParent(self)
        self.hub = SyncHub(self.original)
        self.hub.setParent(self)
        self.editor = self.hub.bridge(effect)
        self.hub.changed.connect(self.changed)
        self.closed = False
        self.network_ready = network_installed()
        if not self.network_ready:
            self.hub.timer.stop()
            self.hub.problem = "Network Connection must be installed to use Ableton Link (Sync)."

    def readback(self, _message):
        if not self.closed and self.network_ready:
            self.original.changed.emit()

    @Slot(str, str, float)
    def change(self, kind, symbol, value):
        if not self.closed and self.network_ready:
            self.editor.change(kind, symbol, value)

    @Slot(bool)
    def transport(self, play):
        if not self.closed and self.network_ready:
            self.editor.transport(play)

    @Slot(str)
    def selectConnection(self, value):
        if not self.closed and self.network_ready:
            self.editor.selectConnection(value)

    @Slot()
    def retryConnection(self):
        if not self.closed and self.network_ready:
            self.editor.retryConnection()

    def close(self):
        if not self.closed:
            self.closed = True
            self.hub.close()

    moduleVersion = Property(str, lambda self: self.module_version, constant=True)
    networkInstalled = Property(bool, lambda self: self.network_ready, constant=True)
    status = Property('QVariantMap', lambda self: self.hub.status_data(), notify=changed)
    error = Property(str, lambda self: self.hub.problem, notify=changed)


def create_backend(effect, api):
    return Backend(effect, api)
