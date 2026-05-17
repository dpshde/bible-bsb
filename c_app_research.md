#CFlipperAppResearchReport

##1.CAppFileStructure

Atypicalmedium-complexityCFlipperZeroapphasthefollowingfiles:

|File|Purpose|
|---|---|
|`application.fam`|Buildmanifest—definesappID,name,entrypoint,dependencies,sources,stacksize|
|`*.c`|Sourcescenes,views,device-logic,protocolhandlers|
|`*.h`|Headers,typedefs,constants,sceneconfigs|
|`scenes/*.c`|Eachscene:menu,read,saved,emulate,settings,etc.|
|`views/*.c`|Customviews(e.g.dictattack,loclass)|
|`application.fam`|Buildmanifest|

**Example:picopass**
```
picopass/
├──application.fam
├──picopass.c
├──picopass_i.h
├──picopass_device.c/.h
├──scenes/
│├──picopass_scene_start.c
│├──picopass_scene_read_card.c
│├──picopass_scene_emulate.c
│└──...
└──views/
├──dict_attack.c/.h
└──loclass.c/.h
```

---

##2.`application.fam`foraCFAP

CappssimplylistCsourcefilesanddeclaretheirrequirements:

```python
App(
appid="my_app",
name="MyApp",
apptype=FlipperAppType.EXTERNAL,
entry_point="my_app_main",
sources=["*.c"],
requires=[
"storage",
"gui",
],
stack_size=4*1024,
)
```

KeydifferencesfromtheRust/Cargoapproach:
-No`fap_extbuild`—ufbtinvokestheCtoolchaindirectly.
-No`sources=[]`hack.
-`entry_point`istheCfunctionname.

---

##3.ViewDispatcher/ScenePattern

ThecanonicalCpattern:

1.Allocatea`ViewDispatcher`and`SceneManager`.
2.Addviewstothedispatcher(submenu,popup,textinput,widget,customviews).
3.Attachthe`Gui`record.
4.Switchtosceneswith`scene_manager_next_scene(...)`.
5.Run`view_dispatcher_run(...)`.
6.Oncleanup,removeviews,freedispatcherandscene_manager.

**Examplefrompicopass:**
```c
Picopass*picopass=malloc(sizeof(Picopass));
picopass->view_dispatcher=view_dispatcher_alloc();
picopass->scene_manager=scene_manager_alloc(&picopass_scene_handlers,picopass);

view_dispatcher_set_event_callback_context(picopass->view_dispatcher,picopass);
view_dispatcher_set_custom_event_callback(picopass->view_dispatcher,picopass_custom_event_callback);
view_dispatcher_set_navigation_event_callback(picopass->view_dispatcher,picopass_back_event_callback);

picopass->gui=furi_record_open(RECORD_GUI);
view_dispatcher_attach_to_gui(picopass->view_dispatcher,picopass->gui,ViewDispatcherTypeFullscreen);

//Addviews
picopass->submenu=submenu_alloc();
view_dispatcher_add_view(picopass->view_dispatcher,PicopassViewMenu,submenu_get_view(picopass->submenu));
//...repeatforpopup,textinput,widget,etc.

scene_manager_next_scene(picopass->scene_manager,PicopassSceneStart);
view_dispatcher_run(picopass->view_dispatcher);

//Cleanup—mirrorallocorderinreverse
view_dispatcher_remove_view(picopass->view_dispatcher,PicopassViewMenu);
submenu_free(picopass->submenu);
//...
view_dispatcher_free(picopass->view_dispatcher);
scene_manager_free(picopass->scene_manager);
furi_record_close(RECORD_GUI);
free(picopass);
```

**Sceneeventsystem:**
```c
voidpicopass_scene_emulate_on_enter(void*context){
Picopass*picopass=context;
//Setupwidget/UI
widget_reset(widget);
widget_add_string_element(widget,92,25,AlignCenter,AlignTop,FontPrimary,"Emulating");
//StartNFCemulation
picopass_scene_emulate_start(picopass);
view_dispatcher_switch_to_view(picopass->view_dispatcher,PicopassViewWidget);
}

boolpicopass_scene_emulate_on_event(void*context,SceneManagerEventevent){
Picopass*picopass=context;
if(event.type==SceneManagerEventTypeCustom){
if(event.event==GuiButtonTypeRight){
//+1buttonpressed
}
}elseif(event.type==SceneManagerEventTypeBack){
returnscene_manager_previous_scene(picopass->scene_manager);
}
returnfalse;
}

voidpicopass_scene_emulate_on_exit(void*context){
Picopass*picopass=context;
picopass_scene_emulate_stop(picopass);
widget_reset(picopass->widget);
}
```

---

##4.CanvasDrawing

Drawinghappensinsidea`draw_callback`registeredvia`view_port_draw_callback_set`orwithina`View`'sdrawcallback.

**BasicAPI:**
```c
staticvoiddraw_callback(Canvas*canvas,void*ctx){
canvas_clear(canvas);
canvas_set_font(canvas,FontPrimary);
canvas_draw_str(canvas,2,10,"HelloWorld");
canvas_draw_frame(canvas,0,0,128,64);
}
```

**Fonts:**
-`FontPrimary`=5x7char(6pxwide,8pxhigh)
-`FontSecondary`=smallerheaderfont
-`FontKeyboard`=numerickeyboardfont
-`FontBigNumbers`=largedisplaynumbers

**Primitives:**
-`canvas_draw_str(canvas,x,y,text)`
-`canvas_draw_icon(canvas,x,y,&icon_name)`
-`canvas_draw_frame(canvas,x,y,w,h)`
-`canvas_draw_line(canvas,x1,y1,x2,y2)`
-`canvas_set_font(canvas,FontPrimary)`
-`canvas_draw_rframe(canvas,x,y,w,h,r)`(roundedrect)

**Layout:**
-Screen:128x64pixels
-Header:y=8,dividery=10
-Contentstart:y=16
-LINE_HEIGHT=12forreadabletext
-Bottommargin:y=62

**Examplefrombt_trigger:**
```c
staticvoiddraw_callback(Canvas*canvas,void*ctx){
AppStruct*app=ctx;
charbuf[36];
snprintf(buf,sizeof(buf),"%ishots",app->shots);

canvas_clear(canvas);
canvas_draw_frame(canvas,0,0,128,64);
canvas_set_font(canvas,FontPrimary);
canvas_draw_str(canvas,2,10,"iOSIntervalometer");
canvas_set_font(canvas,FontSecondary);
canvas_draw_str(canvas,92,62,"Nem0oo");
if(app->connected){
canvas_draw_icon(canvas,111,2,&I_Ble_connected_15x15);
canvas_draw_icon(canvas,3,19,&I_ButtonDown_7x4);
canvas_draw_str(canvas,13,22,"Delay(insec)");
canvas_draw_str(canvas,71,22,buf);
}
}
```

---

##5.StorageAPI

Forreading/writingfilestotheSDcard:

**Read:**
```c
Storage*storage=furi_record_open(RECORD_STORAGE);
File*file=storage_file_alloc(storage);
boolok=storage_file_open(file,"/ext/apps_data/my_app/data.txt",FSAM_READ,FSOM_OPEN_EXISTING);
if(ok){
uint8_tbuf[1024];
size_tn=storage_file_read(file,buf,sizeof(buf));
//processbuf
}
storage_file_close(file);
storage_file_free(file);
furi_record_close(RECORD_STORAGE);
```

**Write:**
```c
Storage*storage=furi_record_open(RECORD_STORAGE);
File*file=storage_file_alloc(storage);
boolok=storage_file_open(file,"/ext/apps_data/my_app/data.txt",FSAM_WRITE,FSOM_OPEN_ALWAYS);
if(ok){
constchar*text="Hello";
storage_file_write(file,text,strlen(text));
}
storage_file_close(file);
storage_file_free(file);
furi_record_close(RECORD_STORAGE);
```

**Keyhelpers:**
-`STORAGE_APP_DATA_PATH_PREFIX`→`/ext/apps_data/<appid>/`
-`APP_DATA_PATH("file.txt")`→`/ext/apps_data/<appid>/file.txt`
-`EXT_PATH("path")`→`/ext/path`
-Always`storage_file_close()`before`storage_file_free()`—crashotherwise.

---

##6.NFCEmulation

Therearetwopatterns:

###PatternA:File-based(legacy)
1.Writedatavia`storage_file_write(...)`to`/ext/nfc/myfile.nfc`.
2.Launchthebuilt-inNFCappwith`loader_start_with_gui_error(...)`.

###PatternB:Directprotocolemulation(picopass-style)
1.AllocateNFC:```c
Nfc*nfc=nfc_alloc();
```
2.Allocatelistenerwithdeviceprotocoldata:```c
NfcDeviceData*data=malloc(sizeof(NfcDeviceData));
//filldata...
NfcListener*listener=nfc_listener_alloc(nfc,protocol,data);
```
3.Startlistening:```c
nfc_listener_start(listener,listener_callback,context);
```
4.Stopandcleanup:```c
nfc_listener_stop(listener);
nfc_listener_free(listener);
nfc_free(nfc);
```

**NFCsharingviapayload(picopasssharescene):**
```c
voidpicopass_scene_emulate_start(Picopass*picopass){
picopass->listener=picopass_listener_alloc(picopass->nfc,dev_data);
picopass_listener_start(picopass->listener,picopass_scene_listener_callback,picopass);
}

NfcCommandpicopass_scene_listener_callback(PicopassListenerEventevent,void*context){
UNUSED(event);UNUSED(context);
returnNfcCommandContinue;
}
```

---

##7.MemoryManagement

-Heapis~16-32KBfreeforaFAP.
-Usestaticbuffers(pre-allocatedarrays)wherepossible.
-Avoid`malloc()`forlargecontiguousblocks(e.g.64KBuf`Vec::with_capacity(64000)`willcrashduetoheapfragmentation).
-Useincrementalreads:readinto1Kchunksand`extend_from_slice`.
-`stack_size`in`application.fam`setsthestack:e.g.,`stack_size=4*1024`.
-Fliperhas`furi_memmgr_alloc()`butstandard`malloc`/`free`workfine.

**FromAGENTS.md:**
>"OOMcrashesarealmostalwaysheapfragmentation,nottotalmemoryexhaustion."
>"Neverallocatealargebufferupfront.Readinsmallfixedchunks(e.g.1KB)."

---

##8.BuildCommandswithufbt

Onthissystem,ufbtis**NOTinstalled**.Installwith:
```sh
pip3installufbt
```

Commoncommands:
```sh
ufbtcreateAPPID=my_app#generateskeleton
ufbt#buildtheapp
ufbtlaunch#build+deploy+runondeviceviaUSB
ufbt--with=FOO#buildwithfirmwaresourcesforIDEheaders
ufbtformat#clang-formatallsource
```

Outputgoesto`dist/f7-CURRENT/my_app.fap`.

---

##9.`fetch_bsb.py`DataFormat

`scripts/fetch_bsb.py`buildsBSBchapterfilesfromanArweave-hostedJSONLdataset.

**Outputdirectorytree:**
```
bsb_sd/
├──gen/
│├──1.json
│├──2.json
│└──...
├──exo/
│├──1.json
│└──...
└──...
```

**EachchapterJSONfile:**
```json
{"verses":[{"n":1,"t":"Inthebeginning..."},{"n":2,"t":"Andtheearth..."}]}
```

**Fields:**
-`n`:versenumber(uint)
-`t`:versetext(string)

**CollectionJSON**(`/ext/apps_data/kindled_spark/collection.json`):
```json
{"version":"kindled-flipper-v2","passages":[{"scripture_ref":"GEN.1.1","scripture_display_ref":"Genesis1:1","scripture_translation":"BSB","book_index":0,"chapter":1,"start_verse":1,"end_verse":1,"captured_at":"...","note":""}]}
```

---

##10.KeyDifferencesfromRusttoC

|Aspect|Rust(`flipperzero-rs`)|C(native)||---|---|---||Entrypoint|`rt::entry!`macro|`intmy_app_main(void*p)`||Memory|Vec/String—heapfragrisk|Staticarrays,`malloc`,manual`free`||Views|Manual`ViewPort`+`Gui`|`ViewDispatcher`+`View`system||Drawing|RustwrappersaroundCAPI|SameCAPI,directpointers||Storage|`StorageFile`wrapper|`Storage*`,`File*`handles||NFC|Wrapperstructs+helpers|`Nfc*`,`NfcDeviceData`structs||Strings|`CStr`,`CString`|Null-terminated`char*`||Build|Cargo+`.cargo/config.toml`|ufbt/SCons||Eventloop|`furi_message_queue`|Samequeue,butexplicitdispatch||Structlifecycle|RAII/drop|Manualalloc/free||Stacksize|`rt::manifest!`+`application.fam`|`application.fam`only||Icon|Embeddedautomatically|`fap_icon_assets`+`*.icon`files||

---

##11.RecommendedCReimplementationPlan

1.Generateskeletonwith`ufbtcreateAPPID=bible_bsb`.
2.Implement`bible_app_alloc()`and`bible_app_free()`mirroring`picopass_alloc()`.
3.Addviews:submenu(booklist),widget(reader),textinput(search),popup(loading).
4.ImplementscenesforBookList,ChapterList,VerseSelect,Reader,Collection,NfcShare.
5.Reuse`fetch_bsb.py`forSDcarddataprep.
6.Implementstorageforcollection.jsonusing`storage_file_alloc/open/read/write/close/free`.
7.ImplementNFCemulationwith`nfc_alloc()`+`nfc_listener_alloc()`+`nfc_listener_start()`.
8.Usestaticbuffers(1KBchunkreads)fortextloadingtoavoidheapfragmentation.
9.MatchcanvaslayoutfromRust:`FontPrimary`,lineheight12px,margins2px.

