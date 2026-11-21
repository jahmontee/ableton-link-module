// SPDX-License-Identifier: GPL-2.0-or-later
// Keep all filesystem checks and library loading outside the audio callback.
#include <lv2/core/lv2.h>
#include <lv2/state/state.h>
#include <array>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <fcntl.h>
#include <memory>
#include <string>
#include <sys/stat.h>
#include <unistd.h>

namespace {
constexpr const char* uri="urn:hector-community:link:sync";
bool trustedFile(const char* name) {
  int fd=open(name,O_RDONLY|O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC);
  if(fd<0)return false;
  struct stat s{},current{};
  bool valid=fstat(fd,&s)==0 && S_ISREG(s.st_mode) && s.st_uid==0
    && !(s.st_mode&0022) && s.st_size>0 && s.st_size<2*1024*1024
    && lstat(name,&current)==0 && current.st_dev==s.st_dev && current.st_ino==s.st_ino;
  close(fd);return valid;
}
bool networkInstalled() {
  return trustedFile("/usr/local/lib/hector-network-panel/backend.py")
    && trustedFile("/etc/systemd/system/hector-network-panel.service");
}
std::string enginePath() {
  Dl_info info{};
  if(!dladdr(reinterpret_cast<void*>(&enginePath),&info))return {};
  std::unique_ptr<char,decltype(&free)> path(realpath(info.dli_fname,nullptr),&free);
  if(!path)return {};
  const std::string own(path.get());
  auto slash=own.find_last_of('/');if(slash==std::string::npos)return {};
  const auto name=own.substr(slash+1);
  // Installed manager assets use <release-sha>.so plus <release-sha>.pkg/.
  if(name.size()==67 && name.substr(64)==".so" && name.find_first_not_of("0123456789abcdef")==64)
    return own.substr(0,own.size()-3)+".pkg/editor/engine.so";
  // The signed native source/test bundle has module.so and editor/engine.so.
  if(name=="module.so")return own.substr(0,slash)+"/editor/engine.so";
  return {};
}
struct Plugin {
  std::array<float*,15> ports{};
  void* library=nullptr;
  const LV2_Descriptor* engine=nullptr;
  LV2_Handle instance=nullptr;
  ~Plugin(){if(instance && engine)engine->cleanup(instance);if(library)dlclose(library);}
};
LV2_Handle instantiate(const LV2_Descriptor*,double rate,const char* bundle,const LV2_Feature* const* features) {
  if(!std::isfinite(rate) || rate<8000 || rate>192000)return nullptr;
  try {
    auto p=std::make_unique<Plugin>();
    // Installation/removal of Network Connection is a restart-bound operation.
    // With no provider, do not even load the timing engine or its worker.
    if(!networkInstalled())return p.release();
    const auto path=enginePath();if(path.empty())return nullptr;
    p->library=dlopen(path.c_str(),RTLD_NOW|RTLD_LOCAL);if(!p->library)return nullptr;
    auto entry=reinterpret_cast<const LV2_Descriptor*(*)(uint32_t)>(dlsym(p->library,"lv2_descriptor"));
    if(!entry)return nullptr;
    p->engine=entry(0);
    if(!p->engine || strcmp(p->engine->URI,uri))return nullptr;
    p->instance=p->engine->instantiate(p->engine,rate,bundle,features);
    if(!p->instance)return nullptr;
    return p.release();
  }catch(...){return nullptr;}
}
void connect(LV2_Handle h,uint32_t port,void* data) {
  auto& p=*static_cast<Plugin*>(h);if(port>=15)return;p.ports[port]=static_cast<float*>(data);
  if(p.instance)p.engine->connect_port(p.instance,port,data);
}
void activate(LV2_Handle h){auto& p=*static_cast<Plugin*>(h);if(p.instance && p.engine->activate)p.engine->activate(p.instance);}
void deactivate(LV2_Handle h){auto& p=*static_cast<Plugin*>(h);if(p.instance && p.engine->deactivate)p.engine->deactivate(p.instance);}
void run(LV2_Handle h,uint32_t frames) {
  auto& p=*static_cast<Plugin*>(h);
  if(p.instance){p.engine->run(p.instance,frames);return;}
  if(!frames)return;
  for(auto port:{6,11,12})if(p.ports[port])*p.ports[port]=0;
  for(auto port:{7,8,9,10})if(p.ports[port])
    for(uint32_t i=0;i<frames;++i)p.ports[port][i]=0;
}
void cleanup(LV2_Handle h){delete static_cast<Plugin*>(h);}
LV2_State_Status save(LV2_Handle h,LV2_State_Store_Function fn,LV2_State_Handle state,uint32_t flags,const LV2_Feature* const* features) {
  auto& p=*static_cast<Plugin*>(h);
  const auto* ext=p.instance?static_cast<const LV2_State_Interface*>(p.engine->extension_data(LV2_STATE__interface)):nullptr;
  return ext?ext->save(p.instance,fn,state,flags,features):LV2_STATE_SUCCESS;
}
LV2_State_Status restore(LV2_Handle h,LV2_State_Retrieve_Function fn,LV2_State_Handle state,uint32_t flags,const LV2_Feature* const* features) {
  auto& p=*static_cast<Plugin*>(h);
  const auto* ext=p.instance?static_cast<const LV2_State_Interface*>(p.engine->extension_data(LV2_STATE__interface)):nullptr;
  return ext?ext->restore(p.instance,fn,state,flags,features):LV2_STATE_SUCCESS;
}
const void* extension(const char* name){static const LV2_State_Interface state{save,restore};return !strcmp(name,LV2_STATE__interface)?&state:nullptr;}
const LV2_Descriptor descriptor{uri,instantiate,connect,activate,run,deactivate,cleanup,extension};
}
extern "C" LV2_SYMBOL_EXPORT const LV2_Descriptor* lv2_descriptor(uint32_t i){return i==0?&descriptor:nullptr;}
