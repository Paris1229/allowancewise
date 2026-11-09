import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const navy = Color(0xFF1B2A6B),
    amber = Color(0xFFFFB400),
    mint = Color(0xFF12B886),
    bg = Color(0xFFF5F7FF),
    darkBg = Color(0xFF0D1324),
    darkSurface = Color(0xFF171F32),
    darkNavy = Color(0xFF243765);
final df = DateFormat('yyyy-MM-dd');
const cats = <String, IconData>{
  'Food': Icons.restaurant,
  'Transport': Icons.directions_bus,
  'School': Icons.menu_book,
  'Bills': Icons.phone_android,
  'Fun': Icons.sports_esports,
  'Other': Icons.category,
};

class Expense {
  int? id;
  double amount;
  String category, note, date;
  Expense(
      {this.id,
      required this.amount,
      required this.category,
      this.note = '',
      required this.date});
  Map<String, Object?> toMap() => {
        'id': id,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date
      };
  factory Expense.from(Map m) => Expense(
      id: m['id'],
      amount: (m['amount'] as num).toDouble(),
      category: m['category'],
      note: m['note'] ?? '',
      date: m['date']);
}

class DB {
  static Database? _d;
  static Future<Database> get db async => _d ??= await openDatabase(
          p.join(await getDatabasesPath(), 'allowancewise.db'),
          version: 1, onCreate: (d, v) async {
        await d.execute(
            'CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT,amount REAL NOT NULL,category TEXT NOT NULL,note TEXT,date TEXT NOT NULL)');
        await d
            .execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT)');
      });
  static Future<List<Expense>> all() async =>
      (await (await db).query('expenses', orderBy: 'date DESC,id DESC'))
          .map(Expense.from)
          .toList();
  static Future<void> save(Expense e) async {
    final d = await db;
    if (e.id == null) {
      await d.insert('expenses', e.toMap()..remove('id'));
    } else {
      await d.update('expenses', e.toMap(), where: 'id=?', whereArgs: [e.id]);
    }
  }

  static Future<void> del(int id) async =>
      (await db).delete('expenses', where: 'id=?', whereArgs: [id]);
  static Future<void> clear() async => (await db).delete('expenses');
  static Future<String> get(String k, String def) async {
    final r =
        await (await db).query('settings', where: 'key=?', whereArgs: [k]);
    return r.isEmpty ? def : r.first['value'] as String;
  }

  static Future<void> put(String k, String v) async =>
      (await db).insert('settings', {'key': k, 'value': v},
          conflictAlgorithm: ConflictAlgorithm.replace);
}

void main() => runApp(const AllowanceWiseApp());

class AllowanceWiseApp extends StatefulWidget {
  const AllowanceWiseApp({super.key});

  @override
  State<AllowanceWiseApp> createState() => _AllowanceWiseAppState();
}

class _AllowanceWiseAppState extends State<AllowanceWiseApp> {
  bool isDark = false;

  @override
  void initState() {
    super.initState();
    loadTheme();
  }

  Future<void> loadTheme() async {
    final saved = await DB.get('darkMode', 'false');
    if (!mounted) return;
    setState(() => isDark = saved == 'true');
  }

  Future<void> changeTheme(bool value) async {
    await DB.put('darkMode', value.toString());
    if (mounted) setState(() => isDark = value);
  }

  ThemeData makeTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: brightness,
    ).copyWith(
      primary: dark ? const Color(0xFFB7C6FF) : navy,
      onPrimary: dark ? const Color(0xFF18254D) : Colors.white,
      surface: dark ? darkSurface : Colors.white,
      onSurface: dark ? const Color(0xFFE5E9F3) : const Color(0xFF20243A),
      surfaceContainerHighest:
          dark ? const Color(0xFF202B42) : const Color(0xFFE9ECF5),
      onSurfaceVariant:
          dark ? const Color(0xFFADB8CE) : const Color(0xFF62677A),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: dark ? darkBg : bg,
      appBarTheme: AppBarTheme(backgroundColor: dark ? darkBg : bg),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: makeTheme(Brightness.light),
        darkTheme: makeTheme(Brightness.dark),
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        home: Home(isDark: isDark, onThemeChanged: changeTheme),
      );
}

class Home extends StatefulWidget {
  final bool isDark;
  final Future<void> Function(bool) onThemeChanged;

  const Home({super.key, required this.isDark, required this.onThemeChanged});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Expense> items = [];
  double budget = 1000;
  String cur = '₱';
  int tab = 0;
  String q = '';
  String? filter;
  final bc = TextEditingController(), cc = TextEditingController();
  String? berr;

  @override
  void initState() {
    super.initState();
    load(first: true);
  }

  Future<void> load({bool first = false}) async {
    final l = await DB.all();
    final b = double.tryParse(await DB.get('budget', '1000')) ?? 1000;
    final c = await DB.get('currency', '₱');
    if (!mounted) return;
    setState(() {
      items = l;
      budget = b;
      cur = c;
    });
    if (first) {
      bc.text = b.toStringAsFixed(0);
      cc.text = c;
    }
  }

  String money(double v) => '$cur${NumberFormat('#,##0.00').format(v)}';
  DateTime get monday {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day)
        .subtract(Duration(days: n.weekday - 1));
  }

  List<Expense> get week {
    final a = df.format(monday),
        b = df.format(monday.add(const Duration(days: 6)));
    return items
        .where((e) => e.date.compareTo(a) >= 0 && e.date.compareTo(b) <= 0)
        .toList();
  }

  double get spent => week.fold(0.0, (s, e) => s + e.amount);

  Future<void> openForm([Expense? e]) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => ExpenseForm(e: e)));
    load();
  }

  Widget tile(Expense e, int i) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
        key: ValueKey('e${e.id}'),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 300 + i * 50),
        builder: (_, v, c) => Opacity(
            opacity: v,
            child:
                Transform.translate(offset: Offset(0, 16 * (1 - v)), child: c)),
        child: Dismissible(
            key: ValueKey('d${e.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(18)),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white)),
            onDismissed: (_) async {
              final copy = Expense(
                  amount: e.amount,
                  category: e.category,
                  note: e.note,
                  date: e.date);
              await DB.del(e.id!);
              await load();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Expense deleted'),
                  action: SnackBarAction(
                      label: 'UNDO',
                      onPressed: () async {
                        await DB.save(copy);
                        load();
                      })));
            },
            child: Card(
                elevation: 0,
                color: colors.surface,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                child: ListTile(
                    onTap: () => openForm(e),
                    leading: CircleAvatar(
                        backgroundColor: amber.withValues(alpha: .25),
                        child: Icon(cats[e.category] ?? Icons.category,
                            color: colors.primary)),
                    title: Text(
                        e.note.isEmpty
                            ? e.category
                            : '${e.category} - ${e.note}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        DateFormat('MMM d, y').format(DateTime.parse(e.date))),
                    trailing: Text('-${money(e.amount)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.primary))))));
  }

  Widget homeTab() {
    final colors = Theme.of(context).colorScheme;
    final s = spent, left = budget - s;
    final double ratio =
        budget <= 0 ? 0 : (s / budget).clamp(0.0, 1.0).toDouble();
    final over = s > budget, warn = ratio >= 0.8;
    final status = over
        ? 'Over budget'
        : warn
            ? 'Almost out'
            : 'On track';
    final col = over
        ? Colors.redAccent
        : warn
            ? Colors.orange
            : mint;
    final icon = over
        ? Icons.warning_amber_rounded
        : warn
            ? Icons.error_outline
            : Icons.check_circle;
    final byCat = <String, double>{for (final k in cats.keys) k: 0};
    for (final e in week) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }
    final mx = byCat.values.fold(0.0, (a, b) => a > b ? a : b);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: widget.isDark ? darkNavy : navy,
              borderRadius: BorderRadius.circular(24)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${DateFormat('MMM d').format(monday)} - ${DateFormat('MMM d').format(monday.add(const Duration(days: 6)))}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(money(left < 0 ? 0 : left),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800)),
            Text('left of ${money(budget)} this week',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 14),
            TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOut,
                builder: (_, v, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                        value: v,
                        minHeight: 14,
                        color: col,
                        backgroundColor: Colors.white24))),
            const SizedBox(height: 10),
            Row(children: [
              Icon(icon, color: col, size: 22),
              const SizedBox(width: 6),
              Text(status,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('Spent ${money(s)}',
                  style: const TextStyle(color: Colors.white70))
            ]),
          ])),
      const SizedBox(height: 20),
      const Text('This week by category',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final k in cats.keys)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(cats[k], size: 20, color: colors.primary),
              const SizedBox(width: 8),
              SizedBox(width: 78, child: Text(k)),
              Expanded(
                  child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: mx == 0 ? 0 : byCat[k]! / mx),
                      duration: const Duration(milliseconds: 700),
                      builder: (_, v, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                              value: v,
                              minHeight: 10,
                              color: amber,
                              backgroundColor:
                                  colors.onSurface.withValues(alpha: .12))))),
              SizedBox(
                  width: 84,
                  child: Text(money(byCat[k]!),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12))),
            ])),
      const SizedBox(height: 20),
      const Text('Recent expenses',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (items.isEmpty)
        const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('No expenses yet. Tap + to add one.'))),
      for (var i = 0; i < items.length && i < 3; i++) tile(items[i], i),
    ]);
  }

  Widget listTab() {
    final colors = Theme.of(context).colorScheme;
    final l = items
        .where((e) =>
            (filter == null || e.category == filter) &&
            (q.isEmpty ||
                '${e.note} ${e.category}'
                    .toLowerCase()
                    .contains(q.toLowerCase())))
        .toList();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: InputDecoration(
                  hintText: 'Search expenses',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none)))),
      SizedBox(
          height: 50,
          child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final k in [null, ...cats.keys])
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                          label: Text(k ?? 'All'),
                          selected: filter == k,
                          onSelected: (_) => setState(() => filter = k)))
              ])),
      Expanded(
          child: l.isEmpty
              ? const Center(child: Text('No matching expenses.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: l.length,
                  itemBuilder: (_, i) => tile(l[i], i))),
    ]);
  }

  Widget settingsTab() {
    final colors = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      SegmentedButton<bool>(segments: const [
        ButtonSegment(
            value: false, icon: Icon(Icons.light_mode), label: Text('Light')),
        ButtonSegment(
            value: true, icon: Icon(Icons.dark_mode), label: Text('Dark')),
      ], selected: {
        widget.isDark
      }, onSelectionChanged: (value) => widget.onThemeChanged(value.first)),
      const SizedBox(height: 24),
      const Text('Weekly allowance',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextField(
          controller: bc,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: 'Weekly budget',
              errorText: berr,
              filled: true,
              fillColor: colors.surface,
              border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(
          controller: cc,
          maxLength: 3,
          decoration: InputDecoration(
              labelText: 'Currency symbol',
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder())),
      FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: widget.isDark ? darkNavy : navy,
              minimumSize: const Size.fromHeight(52)),
          onPressed: () async {
            final v = double.tryParse(bc.text.trim().replaceAll(',', ''));
            if (v == null || v <= 0) {
              setState(() => berr = 'Enter a budget greater than 0.');
              return;
            }
            await DB.put('budget', v.toString());
            await DB.put(
                'currency', cc.text.trim().isEmpty ? '₱' : cc.text.trim());
            setState(() => berr = null);
            await load();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings saved')));
            }
          },
          child: const Text('Save settings')),
      const SizedBox(height: 28),
      OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: Colors.red),
          icon: const Icon(Icons.delete_forever),
          label: const Text('Delete all expenses'),
          onPressed: () async {
            final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                        title: const Text('Delete all expenses?'),
                        content: const Text('This cannot be undone.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Delete'))
                        ]));
            if (ok == true) {
              await DB.clear();
              load();
            }
          }),
      const SizedBox(height: 24),
      Center(
          child: Text('AllowanceWise v1.0\nData is stored only on this phone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['AllowanceWise', 'Expenses', 'Settings'];
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: amber, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.savings,
                    color: Theme.of(context).colorScheme.onPrimary)),
            const SizedBox(width: 10),
            Text(titles[tab],
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary))
          ])),
      body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: KeyedSubtree(
              key: ValueKey(tab),
              child: [homeTab(), listTab(), settingsTab()][tab])),
      floatingActionButton: tab == 2
          ? null
          : FloatingActionButton.extended(
              backgroundColor: widget.isDark ? darkNavy : navy,
              foregroundColor: Colors.white,
              onPressed: () => openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add expense')),
      bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long), label: 'Expenses'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Settings')
          ]),
    );
  }
}

class ExpenseForm extends StatefulWidget {
  final Expense? e;
  const ExpenseForm({super.key, this.e});
  @override
  State<ExpenseForm> createState() => _FormState();
}

class _FormState extends State<ExpenseForm> {
  late final amt = TextEditingController(
      text: widget.e == null ? '' : widget.e!.amount.toString());
  late final note = TextEditingController(text: widget.e?.note ?? '');
  late String cat = widget.e?.category ?? 'Food';
  late String date = widget.e?.date ?? df.format(DateTime.now());
  String? err;

  Future<void> save() async {
    final raw = amt.text.trim().replaceAll(',', '');
    final v = double.tryParse(raw);
    String? m;
    if (raw.isEmpty) {
      m = 'Please enter an amount.';
    } else if (v == null) {
      m = 'Amount must be a number.';
    } else if (v <= 0) {
      m = 'Amount must be greater than 0.';
    } else if (v > 1000000) {
      m = 'Amount is too large.';
    }
    if (m != null) {
      setState(() => err = m);
      return;
    }
    await DB.save(Expense(
        id: widget.e?.id,
        amount: v!,
        category: cat,
        note: note.text.trim(),
        date: date));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(widget.e == null ? 'Add expense' : 'Edit expense',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          TextField(
              controller: amt,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'Amount *',
                  errorText: err,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: const OutlineInputBorder())),
          const SizedBox(height: 16),
          const Text('Category'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final k in cats.keys)
              ChoiceChip(
                  avatar: Icon(cats[k], size: 18),
                  label: Text(k),
                  selected: cat == k,
                  onSelected: (_) => setState(() => cat = k))
          ]),
          const SizedBox(height: 16),
          TextField(
              controller: note,
              maxLength: 40,
              decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder())),
          OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.event),
              label: Text('Date: $date'),
              onPressed: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.parse(date),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100));
                if (d != null) setState(() => date = df.format(d));
              }),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
                child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: save,
                    child: const Text('Save'))),
          ]),
        ]),
      );
}
