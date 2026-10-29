import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

const navy = Color(0xFF10243A);
const teal = Color(0xFF16B8A6);

/// Consistent UniLife brand mark used throughout the application.
class UniLifeMark extends StatelessWidget {
  final double size;
  final bool light;
  const UniLifeMark({super.key, this.size = 44, this.light = false});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [teal, Color(0xFF167F83)]),
      borderRadius: BorderRadius.circular(size * .28),
      border: Border.all(color: light ? Colors.white38 : Colors.transparent),
      boxShadow: [BoxShadow(color: teal.withOpacity(.18), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Icon(Icons.school_rounded, color: Colors.white, size: size * .58),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DB.instance.database;
  runApp(const UniLifeApp());
}

class DB {
  DB._();
  static final instance = DB._();
  Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = p.join(await getDatabasesPath(), 'unilife.db');
    _database = await openDatabase(path, version: 3, onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    }, onCreate: (db, version) async {
      await db.execute('CREATE TABLE profile(id INTEGER PRIMARY KEY CHECK(id=1), name TEXT, university TEXT, college TEXT, department TEXT, level TEXT, year TEXT, semester TEXT)');
      await db.execute('CREATE TABLE subjects(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, details TEXT DEFAULT "")');
      await db.execute('CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, details TEXT DEFAULT "", due TEXT DEFAULT "", status TEXT DEFAULT "قيد الإنجاز", subject_id INTEGER)');
      await db.execute('CREATE TABLE projects(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, details TEXT DEFAULT "", due TEXT DEFAULT "", status TEXT DEFAULT "قيد التنفيذ", subject_id INTEGER)');
      await db.execute('CREATE TABLE attendance(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, details TEXT DEFAULT "", due TEXT DEFAULT "", status TEXT DEFAULT "حاضر", subject_id INTEGER)');
      await db.execute('CREATE TABLE grades(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, details TEXT DEFAULT "", due TEXT DEFAULT "", status TEXT DEFAULT "", subject_id INTEGER)');
      await db.execute('CREATE TABLE schedule(id INTEGER PRIMARY KEY AUTOINCREMENT, subject TEXT NOT NULL, day TEXT NOT NULL, startTime TEXT DEFAULT "", endTime TEXT DEFAULT "", room TEXT DEFAULT "", notes TEXT DEFAULT "")');
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('CREATE TABLE schedule(id INTEGER PRIMARY KEY AUTOINCREMENT, subject TEXT NOT NULL, day TEXT NOT NULL, startTime TEXT DEFAULT "", endTime TEXT DEFAULT "", room TEXT DEFAULT "", notes TEXT DEFAULT "")');
      }
      if (oldVersion < 3) {
        await db.execute('ALTER TABLE tasks ADD COLUMN subject_id INTEGER');
        await db.execute('ALTER TABLE projects ADD COLUMN subject_id INTEGER');
        await db.execute('ALTER TABLE attendance ADD COLUMN subject_id INTEGER');
        await db.execute('ALTER TABLE grades ADD COLUMN subject_id INTEGER');
      }
    });
    return _database!;
  }
  Future<Map<String,Object?>?> profile() async {
    final r = await (await database).query('profile', where: 'id=1');
    return r.isEmpty ? null : r.first;
  }
  Future<void> saveProfile(Map<String,Object?> data) async {
    await (await database).insert('profile', {'id':1,...data}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<Map<String,Object?>>> rows(String table) async => (await database).query(table, orderBy:'id DESC');
  Future<void> insert(String table, Map<String,Object?> data) async => (await database).insert(table,data);
  Future<void> update(String table, int id, Map<String,Object?> data) async => (await database).update(table,data,where:'id=?',whereArgs:[id]);
  Future<void> delete(String table, int id) async => (await database).delete(table,where:'id=?',whereArgs:[id]);
  Future<int> count(String table) async {
    final r=await (await database).rawQuery('SELECT COUNT(*) n FROM $table');
    return Sqflite.firstIntValue(r) ?? 0;
  }
}

class UniLifeApp extends StatefulWidget {
  const UniLifeApp({super.key});
  @override State<UniLifeApp> createState()=>_UniLifeAppState();
}
class _UniLifeAppState extends State<UniLifeApp> {
  bool dark=false;
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'UniLife', debugShowCheckedModeBanner:false, themeMode:dark?ThemeMode.dark:ThemeMode.light,
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:teal,primary:navy),scaffoldBackgroundColor:const Color(0xFFF3F7FA),appBarTheme:const AppBarTheme(backgroundColor:navy,foregroundColor:Colors.white,elevation:0,centerTitle:false),cardTheme:CardThemeData(elevation:1,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),margin:EdgeInsets.zero),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(14)))),navigationBarTheme:const NavigationBarThemeData(height:68,indicatorColor:Color(0x3316B8A6))),
    darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorScheme:ColorScheme.fromSeed(seedColor:teal,brightness:Brightness.dark),appBarTheme:const AppBarTheme(backgroundColor:navy,foregroundColor:Colors.white)),
    home:Directionality(textDirection:TextDirection.rtl,child:Gate(onTheme:(v)=>setState(()=>dark=v))),
  );
}
class Gate extends StatefulWidget {
  final ValueChanged<bool> onTheme;
  const Gate({super.key,required this.onTheme});
  @override State<Gate> createState()=>_GateState();
}
class _GateState extends State<Gate> {
  bool loading=true, configured=false;
  @override void initState(){super.initState();check();}
  Future<void> check() async {
    final prof=await DB.instance.profile();
    final prefs=await SharedPreferences.getInstance();
    if(!mounted)return;
    setState(()=>{loading=false,configured=prof!=null});
    widget.onTheme(prefs.getBool('dark')??false);
  }
  @override Widget build(BuildContext context) {
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    return configured?Home(onTheme:widget.onTheme):Welcome(onSaved:()=>setState(()=>configured=true));
  }
}
class Welcome extends StatelessWidget {
  final VoidCallback onSaved;
  const Welcome({super.key,required this.onSaved});
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Padding(
    padding:const EdgeInsets.all(25),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Spacer(),const Center(child:UniLifeMark(size:94)),const SizedBox(height:24),
      const Text('حياة الطالب الجامعي',textAlign:TextAlign.center,style:TextStyle(fontSize:29,fontWeight:FontWeight.bold)),
      const Text('UniLife',textAlign:TextAlign.center,style:TextStyle(fontSize:22,color:teal,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),const Text('نظّم حياتك الجامعية بذكاء.',textAlign:TextAlign.center,style:TextStyle(fontSize:17)),
      const SizedBox(height:18),const Text('نظّم المواد والحضور والواجبات والمشاريع والدرجات. بياناتك محفوظة على هاتفك دون تسجيل دخول أو إنترنت.'),
      const Spacer(),FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ProfileForm(onSaved:onSaved))),child:const Padding(padding:EdgeInsets.all(14),child:Text('إعداد ملفي الأكاديمي'))),
      const SizedBox(height:12),const Text('تطوير: م/ محمد عبدالله الكلالي',textAlign:TextAlign.center,style:TextStyle(fontSize:12)),const SizedBox(height:12)
    ]))));
}
class ProfileForm extends StatefulWidget {
  final VoidCallback onSaved; final Map<String,Object?>? initial;
  const ProfileForm({super.key,required this.onSaved,this.initial});
  @override State<ProfileForm> createState()=>_ProfileFormState();
}
class _ProfileFormState extends State<ProfileForm>{
  final form=GlobalKey<FormState>();
  final labels=const {'name':'اسم الطالب','university':'الجامعة','college':'الكلية','department':'القسم / التخصص','level':'المستوى الدراسي','year':'العام الدراسي','semester':'الفصل الدراسي'};
  late final Map<String,TextEditingController> ctrls;
  @override void initState(){super.initState();ctrls={for(final e in labels.entries)e.key:TextEditingController(text:'${widget.initial?[e.key]??''}')};}
  @override void dispose(){for(final c in ctrls.values){c.dispose();}super.dispose();}
  Future<void> save()async{
    if(!form.currentState!.validate())return;
    await DB.instance.saveProfile({for(final k in labels.keys)k:ctrls[k]!.text.trim()});
    if(!mounted)return;
    if(widget.initial!=null){Navigator.pop(context,true);}else{widget.onSaved();Navigator.pop(context);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('ملفي الأكاديمي')),body:Form(key:form,child:ListView(padding:const EdgeInsets.all(20),children:[
    const Text('أدخل بياناتك مرة واحدة. يمكنك تعديلها لاحقًا من الإعدادات.'),
    const SizedBox(height:18),
    for(final e in labels.entries)...[
      TextFormField(controller:ctrls[e.key],textInputAction:TextInputAction.next,decoration:InputDecoration(labelText:e.value,border:const OutlineInputBorder()),validator:(v)=>v==null||v.trim().isEmpty?'هذا الحقل مطلوب':null),
      const SizedBox(height:13)
    ],
    FilledButton(onPressed:save,child:const Padding(padding:EdgeInsets.all(13),child:Text('حفظ ومتابعة')))
  ])));
}
const sections=[
  ('subjects','المواد الدراسية',Icons.menu_book_rounded),
  ('tasks','الواجبات والتكاليف',Icons.assignment_rounded),
  ('projects','المشاريع',Icons.folder_special_rounded),
  ('attendance','الحضور والغياب',Icons.fact_check_rounded),
  ('grades','الدرجات',Icons.grade_rounded),
];
class Home extends StatefulWidget {
  final ValueChanged<bool> onTheme;
  const Home({super.key,required this.onTheme});
  @override State<Home> createState()=>_HomeState();
}
class _HomeState extends State<Home>{
  // Main tabs: Home, Study, Schedule, Tasks, Profile. Extra tools remain in the drawer.
  int index=0;
  final titles=['الرئيسية','المواد الدراسية','الجدول الدراسي','الواجبات والتكاليف','ملفي','المشاريع','الحضور والغياب','الدرجات'];
  int get selectedTab => index<=1 ? index : index==2 ? 2 : index==3 ? 3 : index==4 ? 4 : 0;
  void goToSection(int section){
    // section order is subjects, tasks, projects, attendance, grades
    const target=[1,3,5,6,7];
    setState(()=>index=target[section.clamp(0,4).toInt()]);
  }
  @override Widget build(BuildContext context){
    final pages=<Widget>[
      Dashboard(onGo:goToSection),
      Records(table:'subjects',title:'المواد الدراسية',icon:Icons.menu_book_rounded),
      const SchedulePage(),
      Records(table:'tasks',title:'الواجبات والتكاليف',icon:Icons.assignment_rounded),
      Settings(onTheme:widget.onTheme),
      Records(table:'projects',title:'المشاريع',icon:Icons.folder_special_rounded),
      Records(table:'attendance',title:'الحضور والغياب',icon:Icons.fact_check_rounded),
      Records(table:'grades',title:'الدرجات',icon:Icons.grade_rounded),
    ];
    return Scaffold(
      appBar:AppBar(
        title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(titles[index],style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
          const Text('UniLife • حياتك الجامعية بتنظيم أسهل',style:TextStyle(fontSize:10,color:Colors.white70)),
        ]),
        leading:Builder(builder:(ctx)=>IconButton(tooltip:'القائمة',onPressed:()=>Scaffold.of(ctx).openDrawer(),icon:const Icon(Icons.menu_rounded))),actions:[Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Container(width:34,height:34,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.15),borderRadius:BorderRadius.circular(10)),child:const UniLifeMark(size:30,light:true))),IconButton(tooltip:'تحديث',onPressed:()=>setState((){}),icon:const Icon(Icons.refresh_rounded)),const SizedBox(width:4)],
      ),
      drawer:Drawer(child:SafeArea(child:Column(children:[
        Container(width:double.infinity,padding:const EdgeInsets.fromLTRB(20,24,20,22),decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topRight,end:Alignment.bottomLeft,colors:[navy,Color(0xFF176D78)])),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          UniLifeMark(size:54,light:true),SizedBox(height:12),
          Text('حياة الطالب الجامعي',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.bold)),
          SizedBox(height:4),Text('نظّم حياتك الجامعية بذكاء.',style:TextStyle(color:Colors.white70)),
        ])),
        Expanded(child:ListView(padding:const EdgeInsets.symmetric(vertical:8),children:[
          const Padding(padding:EdgeInsets.fromLTRB(18,8,18,4),child:Text('القائمة الرئيسية',style:TextStyle(color:teal,fontWeight:FontWeight.bold))),
          for(final item in <(int,String,IconData)>[(0,'الرئيسية',Icons.home_rounded),(1,'المواد الدراسية',Icons.menu_book_rounded),(2,'الجدول الدراسي',Icons.calendar_month_rounded),(3,'الواجبات والتكاليف',Icons.assignment_rounded),(4,'ملفي والإعدادات',Icons.person_rounded)])
            ListTile(leading:Icon(item.$3),title:Text(item.$2),selected:index==item.$1,selectedColor:teal,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),onTap:(){setState(()=>index=item.$1);Navigator.pop(context);}),
          const Divider(indent:16,endIndent:16),
          const Padding(padding:EdgeInsets.fromLTRB(18,4,18,4),child:Text('أدوات دراسية إضافية',style:TextStyle(color:teal,fontWeight:FontWeight.bold))),
          for(final item in <(int,String,IconData)>[(5,'المشاريع',Icons.folder_special_rounded),(6,'الحضور والغياب',Icons.fact_check_rounded),(7,'الدرجات',Icons.grade_rounded)])
            ListTile(leading:Icon(item.$3),title:Text(item.$2),selected:index==item.$1,selectedColor:teal,onTap:(){setState(()=>index=item.$1);Navigator.pop(context);}),
        ])),
        const Padding(padding:EdgeInsets.all(14),child:Text('تطوير: م/ محمد عبدالله الكلالي',style:TextStyle(fontSize:12,color:Colors.grey)))
      ]))),
      body:IndexedStack(index:index,children:pages),
      bottomNavigationBar:NavigationBar(
        selectedIndex:selectedTab,
        onDestinationSelected:(tab)=>setState(()=>index=tab),
        labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
        destinations:const [
          NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home_rounded),label:'الرئيسية'),
          NavigationDestination(icon:Icon(Icons.menu_book_outlined),selectedIcon:Icon(Icons.menu_book_rounded),label:'دراستي'),
          NavigationDestination(icon:Icon(Icons.calendar_month_outlined),selectedIcon:Icon(Icons.calendar_month_rounded),label:'الجدول'),
          NavigationDestination(icon:Icon(Icons.task_alt_outlined),selectedIcon:Icon(Icons.task_alt_rounded),label:'مهامي'),
          NavigationDestination(icon:Icon(Icons.person_outline_rounded),selectedIcon:Icon(Icons.person_rounded),label:'ملفي'),
        ],
      ),
    );
  }
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});
  @override State<SchedulePage> createState()=>_SchedulePageState();
}
class _SchedulePageState extends State<SchedulePage>{
  String day='الأحد';
  final days=const ['السبت','الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس'];
  List<Map<String,Object?>> items=[];
  @override void initState(){super.initState();load();}
  Future<void> load()async{final all=await DB.instance.rows('schedule');if(mounted)setState(()=>items=all.where((e)=>e['day']==day).toList());}
  Future<void> edit([Map<String,Object?>? item])async{
    final result=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>ScheduleForm(days:days,initial:item)));
    if(result==true)load();
  }
  Future<void> remove(int id)async{
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف المحاضرة؟'),content:const Text('سيتم حذف الموعد من جدولك.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));
    if(ok==true){await DB.instance.delete('schedule',id);load();}
  }
  @override Widget build(BuildContext context){
    final cs=Theme.of(context).colorScheme;
    return Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:()=>edit(),icon:const Icon(Icons.add_rounded),label:const Text('إضافة محاضرة')),body:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,90),children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[navy,Color(0xFF167F83)],begin:Alignment.topRight,end:Alignment.bottomLeft),borderRadius:BorderRadius.circular(22)),child:const Row(children:[CircleAvatar(radius:27,backgroundColor:Colors.white24,child:Icon(Icons.calendar_month_rounded,color:Colors.white,size:30)),SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('جدولك الدراسي',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.bold)),SizedBox(height:4),Text('أضف محاضراتك ورتّب أوقاتك بسهولة.',style:TextStyle(color:Colors.white70))]))])),
      const SizedBox(height:18),const Text('أيام الأسبوع',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:10),
      SizedBox(height:44,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:days.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(context,i)=>ChoiceChip(label:Text(days[i]),selected:day==days[i],onSelected:(_){setState(()=>day=days[i]);load();}))),
      const SizedBox(height:16),Row(children:[Expanded(child:Text('محاضرات يوم $day',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold))),Text('${items.length} محاضرة',style:TextStyle(color:cs.primary,fontWeight:FontWeight.bold))]),const SizedBox(height:10),
      if(items.isEmpty)Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(children:[Icon(Icons.event_busy_rounded,size:48,color:cs.primary),const SizedBox(height:10),Text('لا توجد محاضرات يوم $day',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),const SizedBox(height:6),const Text('اضغط «إضافة محاضرة» لتسجيل المادة والوقت والقاعة.',textAlign:TextAlign.center),const SizedBox(height:12),OutlinedButton.icon(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('إضافة أول محاضرة'))])))
      else for(final e in items)Card(margin:const EdgeInsets.only(bottom:9),child:ListTile(leading:Container(width:48,height:48,decoration:BoxDecoration(color:teal.withValues(alpha:.14),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.menu_book_rounded,color:teal)),title:Text('${e['subject']}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${e['startTime']} - ${e['endTime']}\n${e['room']??''}${'${e['notes']??''}'.isNotEmpty?' • ${e['notes']}':''}'),isThreeLine:true,trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')edit(e);if(v=='delete')remove(e['id'] as int);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('تعديل')),PopupMenuItem(value:'delete',child:Text('حذف'))]))),
      const SizedBox(height:12),const Center(child:Text('UniLife • جدولك محفوظ على جهازك',style:TextStyle(color:Colors.grey,fontSize:12)))
    ])));
  }
}
class ScheduleForm extends StatefulWidget{
  final List<String> days;final Map<String,Object?>? initial;
  const ScheduleForm({super.key,required this.days,this.initial});
  @override State<ScheduleForm> createState()=>_ScheduleFormState();
}
class _ScheduleFormState extends State<ScheduleForm>{
  final form=GlobalKey<FormState>();late final TextEditingController subject,start,end,room,notes;late String day;
  @override void initState(){super.initState();final x=widget.initial;subject=TextEditingController(text:'${x?['subject']??''}');start=TextEditingController(text:'${x?['startTime']??''}');end=TextEditingController(text:'${x?['endTime']??''}');room=TextEditingController(text:'${x?['room']??''}');notes=TextEditingController(text:'${x?['notes']??''}');day='${x?['day']??'الأحد'}';}
  @override void dispose(){subject.dispose();start.dispose();end.dispose();room.dispose();notes.dispose();super.dispose();}
  Future<void> save()async{if(!form.currentState!.validate())return;final data={'subject':subject.text.trim(),'day':day,'startTime':start.text.trim(),'endTime':end.text.trim(),'room':room.text.trim(),'notes':notes.text.trim()};if(widget.initial==null){await DB.instance.insert('schedule',data);}else{await DB.instance.update('schedule',widget.initial!['id'] as int,data);}if(mounted)Navigator.pop(context,true);}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.initial==null?'إضافة محاضرة':'تعديل المحاضرة')),body:Form(key:form,child:ListView(padding:const EdgeInsets.all(18),children:[TextFormField(controller:subject,decoration:const InputDecoration(labelText:'اسم المادة',prefixIcon:Icon(Icons.menu_book)),validator:(v)=>v==null||v.trim().isEmpty?'اكتب اسم المادة':null),const SizedBox(height:12),DropdownButtonFormField<String>(value:day,decoration:const InputDecoration(labelText:'اليوم',prefixIcon:Icon(Icons.calendar_today)),items:widget.days.map((d)=>DropdownMenuItem(value:d,child:Text(d))).toList(),onChanged:(v){if(v!=null)setState(()=>day=v);}),const SizedBox(height:12),Row(children:[Expanded(child:TextFormField(controller:start,decoration:const InputDecoration(labelText:'وقت البداية',hintText:'08:00',prefixIcon:Icon(Icons.schedule)),validator:(v)=>v==null||v.trim().isEmpty?'أدخل وقت البداية':null)),const SizedBox(width:10),Expanded(child:TextFormField(controller:end,decoration:const InputDecoration(labelText:'وقت النهاية',hintText:'09:30',prefixIcon:Icon(Icons.schedule_outlined)),validator:(v)=>v==null||v.trim().isEmpty?'أدخل وقت النهاية':null))]),const SizedBox(height:12),TextFormField(controller:room,decoration:const InputDecoration(labelText:'القاعة (اختياري)',prefixIcon:Icon(Icons.location_on_outlined))),const SizedBox(height:12),TextFormField(controller:notes,decoration:const InputDecoration(labelText:'ملاحظات (اختياري)',prefixIcon:Icon(Icons.notes)),maxLines:2),const SizedBox(height:20),FilledButton.icon(onPressed:save,icon:const Icon(Icons.save_rounded),label:const Padding(padding:EdgeInsets.all(13),child:Text('حفظ المحاضرة')))])));
}
class Dashboard extends StatefulWidget {
  final ValueChanged<int> onGo;
  const Dashboard({super.key,required this.onGo});
  @override State<Dashboard> createState()=>_DashboardState();
}
class _DashboardState extends State<Dashboard>{
  Map<String,Object?>? prof; Map<String,int> counts={}; List<Map<String,Object?>> tasks=[];
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    final p=await DB.instance.profile();final c=<String,int>{};
    for(final s in sections){c[s.$1]=await DB.instance.count(s.$1);}
    final t=await DB.instance.rows('tasks');
    if(mounted)setState(()=>{prof=p,counts=c,tasks=t.where((x)=>x['status']!='مكتمل').take(4).toList()});
  }
  @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[
    Container(
      padding:const EdgeInsets.all(20),
      constraints:const BoxConstraints(minHeight:170),
      decoration:BoxDecoration(
        borderRadius:BorderRadius.circular(22),
        boxShadow:[BoxShadow(color:navy.withValues(alpha:.18),blurRadius:16,offset:const Offset(0,7))],
      ),
      child:ClipRRect(
        borderRadius:BorderRadius.circular(16),
        child:Stack(children:[
          Positioned.fill(child:Image.asset('assets/images/university_building.jpg',fit:BoxFit.cover)),
          Positioned.fill(child:Container(color:navy.withValues(alpha:.72))),
          Padding(padding:const EdgeInsets.all(4),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('مرحبًا بك 👋',style:TextStyle(color:Colors.white70)),
            Text('${prof?['name']??'طالب الجامعة'}',style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.bold)),
            Text('${prof?['department']??''} • ${prof?['level']??''}',style:const TextStyle(color:Colors.white)),
            const SizedBox(height:8),Text('${prof?['university']??''} — ${prof?['year']??''}',style:const TextStyle(color:Colors.white70))
          ])),
        ]),
      ),
    ),
    const SizedBox(height:18),const Text('ملخصك الدراسي',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:12),
    GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.48,children:[
      for(int i=0;i<sections.length;i++)InkWell(onTap:()=>widget.onGo(i),child:Card(child:Padding(padding:const EdgeInsets.all(13),child:Row(children:[
        Icon(sections[i].$3,color:teal,size:28),const SizedBox(width:10),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${counts[sections[i].$1]??0}',style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)),Text(sections[i].$2,style:const TextStyle(fontSize:12))
        ]))
      ])))),
    ]),
    const SizedBox(height:18),Row(children:[const Expanded(child:Text('المهام القادمة',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold))),TextButton(onPressed:()=>widget.onGo(1),child:const Text('عرض الكل'))]),
    if(tasks.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(17),child:Text('لا توجد مهام مسجلة. أضف واجباتك ومواعيدها هنا.')))
    else for(final t in tasks)Card(child:ListTile(leading:const Icon(Icons.event_note,color:teal),title:Text('${t['title']}'),subtitle:Text('${t['due']??''} • ${t['status']??''}'))),
    const SizedBox(height:12),const Center(child:Text('UniLife • نظّم حياتك الجامعية بذكاء.',style:TextStyle(fontSize:12,color:Colors.grey)))
  ]));
}
class Records extends StatefulWidget {
  final String table,title;final IconData icon;
  const Records({super.key,required this.table,required this.title,required this.icon});
  @override State<Records> createState()=>_RecordsState();
}
class _RecordsState extends State<Records>{
  List<Map<String,Object?>> data=[];
  @override void initState(){super.initState();load();}
  @override void didUpdateWidget(covariant Records oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.table!=widget.table)load();}
  Future<void> load()async{final r=await DB.instance.rows(widget.table);if(['tasks','projects','attendance','grades'].contains(widget.table)){final subs=await DB.instance.rows('subjects');for(final row in r){final sid=row['subject_id'];final found=subs.where((x)=>x['id']==sid);row['_subjectTitle']=found.isEmpty?'':found.first['title'];}}if(mounted)setState(()=>data=r);}
  Future<void> form([Map<String,Object?>? initial])async{
    final result=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>RecordForm(table:widget.table,title:widget.title,initial:initial)));
    if(result==true)load();
  }
  Future<void> remove(int id)async{
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف السجل؟'),content:const Text('لا يمكن التراجع عن الحذف.'),actions:[
      TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),
      FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))
    ]));
    if(ok==true){await DB.instance.delete(widget.table,id);load();}
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:()=>form(),icon:const Icon(Icons.add_rounded),label:Text('إضافة ${widget.table=='subjects'?'مادة':widget.table=='tasks'?'واجب':widget.table=='projects'?'مشروع':widget.table=='attendance'?'سجل حضور':'درجة'}')),body:RefreshIndicator(onRefresh:load,child:data.isEmpty?ListView(children:[
    const SizedBox(height:100),Icon(widget.icon,size:60,color:teal),const SizedBox(height:14),
    Center(child:Text('لا توجد سجلات في ${widget.title}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))),
    const SizedBox(height:8),const Center(child:Text('اضغط + لإضافة أول سجل.')),
    const SizedBox(height:16),Center(child:FilledButton.icon(onPressed:()=>form(),icon:const Icon(Icons.add),label:const Text('إضافة سجل')))
  ]):ListView.separated(padding:const EdgeInsets.all(14),itemCount:data.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,i){
    final r=data[i];final title='${r['title']??''}';final subtitle=[r['_subjectTitle'] == null || '${r['_subjectTitle']}'.isEmpty ? null : 'المادة: ${r['_subjectTitle']}',r['details'],r['due'],r['status']].where((v)=>v!=null&&'$v'.isNotEmpty).join(' • ');
    final got=widget.table=='grades'?double.tryParse('${r['due']??''}'):null;final total=widget.table=='grades'?double.tryParse('${r['status']??''}'):null;final percent=(got!=null&&total!=null&&total>0)?' • ${(got/total*100).toStringAsFixed(1)}%': '';
    return Card(child:ListTile(leading:CircleAvatar(backgroundColor:teal.withOpacity(.15),child:Icon(widget.icon,color:teal)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text((subtitle.isEmpty?'اضغط للتعديل':subtitle)+percent),onTap:()=>form(r),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')form(r);if(v=='delete')remove(r['id'] as int);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('تعديل')),PopupMenuItem(value:'delete',child:Text('حذف'))])));
  })));
}
class RecordForm extends StatefulWidget {
  final String table,title;final Map<String,Object?>? initial;
  const RecordForm({super.key,required this.table,required this.title,this.initial});
  @override State<RecordForm> createState()=>_RecordFormState();
}
class _RecordFormState extends State<RecordForm>{
  final form=GlobalKey<FormState>();late final Map<String,TextEditingController> c; List<Map<String,Object?>> availableSubjects=[]; int? selectedSubjectId;
  List<(String,String)> get fields {
    if(widget.table=='subjects')return [('title','اسم المادة'),('details','الرمز / المدرس / القاعة / الوقت')];
    if(widget.table=='tasks')return [('title','عنوان التكليف'),('details','ملاحظات'),('due','موعد التسليم'),('status','الحالة: قيد الإنجاز / مكتمل')];
    if(widget.table=='projects')return [('title','اسم المشروع'),('details','وصف المشروع / ملاحظات'),('due','موعد التسليم'),('status','الحالة: قيد التنفيذ / مكتمل')];
    if(widget.table=='attendance')return [('title','اسم سجل الحضور'),('details','ملاحظات'),('due','التاريخ'),('status','الحالة: حاضر / غائب / متأخر / بعذر')];
    return [('title','اسم التقييم'),('details','نوع التقييم / ملاحظات'),('due','الدرجة المحصّلة (رقم)'),('status','الدرجة الكلية (رقم)')];
  }
  @override void initState(){super.initState();c={for(final f in fields)f.$1:TextEditingController(text:'${widget.initial?[f.$1]??''}')};selectedSubjectId=widget.initial?['subject_id'] as int?;loadSubjects();}
  Future<void> loadSubjects() async {final r=await DB.instance.rows('subjects');if(mounted)setState(()=>availableSubjects=r);}
  @override void dispose(){for(final x in c.values){x.dispose();}super.dispose();}
  Future<void> save()async{
    if(!form.currentState!.validate())return;
    final values=<String,Object?>{for(final f in fields)f.$1:c[f.$1]!.text.trim()};if(['tasks','projects','attendance','grades'].contains(widget.table))values['subject_id']=selectedSubjectId;
    if(widget.initial==null){await DB.instance.insert(widget.table,values);}else{await DB.instance.update(widget.table,widget.initial!['id'] as int,values);}
    if(mounted)Navigator.pop(context,true);
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.initial==null?'إضافة — ${widget.title}':'تعديل — ${widget.title}')),body:Form(key:form,child:ListView(padding:const EdgeInsets.all(18),children:[
    if(['tasks','projects','attendance','grades'].contains(widget.table))... [
      DropdownButtonFormField<int>(value: selectedSubjectId != null && availableSubjects.any((x)=>x['id']==selectedSubjectId) ? selectedSubjectId : -1, decoration:const InputDecoration(labelText:'المادة المرتبطة (اختياري)',prefixIcon:Icon(Icons.menu_book_rounded)), items:[const DropdownMenuItem<int>(value:-1,child:Text('بدون ربط بمادة')), ...availableSubjects.map((x)=>DropdownMenuItem<int>(value:x['id'] as int,child:Text('${x['title']}')))], onChanged:(v)=>setState(()=>selectedSubjectId=(v==null||v==-1)?null:v)),
      const SizedBox(height:13),
    ],
    for(final f in fields)...[
      if(f.$1=='status' && widget.table=='tasks')
        DropdownButtonFormField<String>(value: const ['قيد الإنجاز','مكتمل'].contains(c[f.$1]!.text) ? c[f.$1]!.text : 'قيد الإنجاز', decoration:InputDecoration(labelText:f.$2,prefixIcon:const Icon(Icons.check_circle_outline)), items:const ['قيد الإنجاز','مكتمل'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v){if(v!=null)c[f.$1]!.text=v;})
      else if(f.$1=='status' && widget.table=='projects')
        DropdownButtonFormField<String>(value: const ['قيد التنفيذ','مكتمل','متوقف'].contains(c[f.$1]!.text) ? c[f.$1]!.text : 'قيد التنفيذ', decoration:InputDecoration(labelText:f.$2,prefixIcon:const Icon(Icons.flag_outlined)), items:const ['قيد التنفيذ','مكتمل','متوقف'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v){if(v!=null)c[f.$1]!.text=v;})
      else if(f.$1=='status' && widget.table=='attendance')
        DropdownButtonFormField<String>(value: const ['حاضر','غائب','متأخر','بعذر'].contains(c[f.$1]!.text) ? c[f.$1]!.text : 'حاضر', decoration:InputDecoration(labelText:f.$2,prefixIcon:const Icon(Icons.fact_check_outlined)), items:const ['حاضر','غائب','متأخر','بعذر'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v){if(v!=null)c[f.$1]!.text=v;})
      else
        TextFormField(controller:c[f.$1],keyboardType:widget.table=='grades' && (f.$1=='due'||f.$1=='status') ? const TextInputType.numberWithOptions(decimal:true) : TextInputType.text,decoration:InputDecoration(labelText:f.$2,border:const OutlineInputBorder()),validator:(v){if(f.$1=='title'&&(v==null||v.trim().isEmpty))return 'هذا الحقل مطلوب';if(widget.table=='grades'&&(f.$1=='due'||f.$1=='status')){final n=double.tryParse((v??'').trim());if(n==null||n<0)return 'أدخل رقمًا صحيحًا أكبر من أو يساوي صفرًا';if(f.$1=='status'){final got=double.tryParse(c['due']!.text.trim());if(got!=null&&n<got)return 'الدرجة الكلية لا يمكن أن تقل عن الدرجة المحصّلة';}}return null;}),
      const SizedBox(height:13)
    ],
    FilledButton.icon(onPressed:save,icon:const Icon(Icons.save),label:const Padding(padding:EdgeInsets.all(12),child:Text('حفظ السجل')))
  ])));
}
class Settings extends StatefulWidget {
  final ValueChanged<bool> onTheme;
  const Settings({super.key,required this.onTheme});
  @override State<Settings> createState()=>_SettingsState();
}
class _SettingsState extends State<Settings>{
  bool dark=false;Map<String,Object?>? profile;
  @override void initState(){super.initState();load();}
  Future<void> load()async{final prefs=await SharedPreferences.getInstance();final p=await DB.instance.profile();if(mounted)setState(()=>{dark=prefs.getBool('dark')??false,profile=p});}
  Future<void> theme(bool v)async{final prefs=await SharedPreferences.getInstance();await prefs.setBool('dark',v);if(mounted)setState(()=>dark=v);widget.onTheme(v);}
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
    Card(child:ListTile(leading:const Icon(Icons.person),title:Text('${profile?['name']??'الطالب'}'),subtitle:Text('${profile?['university']??''}\n${profile?['college']??''} • ${profile?['department']??''}'),isThreeLine:true,trailing:IconButton(icon:const Icon(Icons.edit),onPressed:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>ProfileForm(onSaved:(){},initial:profile)));load();}))),
    Card(child:SwitchListTile(value:dark,onChanged:theme,secondary:const Icon(Icons.dark_mode),title:const Text('الوضع الليلي'),subtitle:const Text('تغيير مظهر التطبيق'))),
    const Card(child:ListTile(leading:Icon(Icons.offline_bolt,color:teal),title:Text('يعمل دون إنترنت'),subtitle:Text('تُحفظ البيانات على هذا الجهاز.'))),
    const Card(child:ListTile(leading:Icon(Icons.info_outline),title:Text('حول UniLife'),subtitle:Text('حياة الطالب الجامعي\nنظّم حياتك الجامعية بذكاء.\nتطوير: م/ محمد عبدالله الكلالي\nالإصدار 1.0.0'))),
    const Padding(padding:EdgeInsets.all(8),child:Text('تنبيه: حذف بيانات التطبيق أو إلغاء تثبيته قد يؤدي إلى فقدان السجلات المحلية.',style:TextStyle(fontSize:12,color:Colors.grey)))
  ]);
}
