import 'package:flutter/material.dart';
import '../features/storage/store.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});
  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final TextEditingController _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    decoration: const InputDecoration(labelText: 'Add category'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final name = _ctl.text.trim();
                    if (name.isEmpty) return;
                    AppStore.addCategory(name);
                    _ctl.clear();
                    setState(() {});
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: ListView.builder(
              itemCount: AppStore.categories.length,
              itemBuilder: (context, i) {
                final c = AppStore.categories[i];
                final canDelete = i != 0; // keep "No category"
                return Dismissible(
                  key: ValueKey(c.id),
                  direction: canDelete
                      ? DismissDirection.endToStart
                      : DismissDirection.none,
                  confirmDismiss: (_) async => canDelete,
                  onDismissed: (_) {
                    if (!canDelete) return;
                    AppStore.removeCategory(c.id);
                    setState(() {});
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      // replace with your 6 images: cat1.png..cat6.png
                      backgroundImage: AssetImage(
                        'lib/assets/images/cat${c.coverIndex}.png',
                      ),
                    ),
                    title: Text(c.name),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
