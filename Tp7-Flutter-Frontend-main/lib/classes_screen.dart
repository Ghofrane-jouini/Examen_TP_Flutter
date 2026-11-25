import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'classe.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  List<Classe> classes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  void msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  Future<void> load() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/classes"));
      if (res.statusCode == 200) {
        final List raw = jsonDecode(res.body);
        setState(() {
          classes = raw.map((e) => Classe.fromMap(e as Map<String, dynamic>)).toList();
        });
      } else {
        final err = res.body.trim().isNotEmpty ? res.body.trim() : "Erreur ${res.statusCode}";
        msg(err, error: true);
      }
    } catch (e) {
      msg("Impossible de joindre le serveur", error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> showForm({Classe? classe}) async {
    final nomCtrl = TextEditingController(text: classe?.nomClass ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(classe == null ? "Nouvelle classe" : "Modifier la classe"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomCtrl,
                decoration: const InputDecoration(labelText: "Nom de la classe"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Annuler")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Enregistrer")),
        ],
      ),
    );

    if (ok != true || nomCtrl.text.trim().isEmpty) return;

    final body = json.encode({
      'nomClass': nomCtrl.text.trim(),
    });

    try {
      final res = classe == null
          ? await http.post(Uri.parse("$baseUrl/classes"),
              headers: {'Content-Type': 'application/json'}, body: body)
          : await http.put(Uri.parse("$baseUrl/classes/${classe.codClass}"),
              headers: {'Content-Type': 'application/json'}, body: body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        msg("Classe enregistrée");
        load();
      } else {
        final err = res.body.trim().isNotEmpty ? res.body.trim() : "Erreur ${res.statusCode}";
        msg(err, error: true);
      }
    } catch (e) {
      msg("Impossible de joindre le serveur", error: true);
    }
  }

  Future<void> delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmation"),
        content: const Text("Voulez-vous vraiment supprimer cette classe ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.delete(Uri.parse("$baseUrl/classes/$id"));
      if (res.statusCode == 200 || res.statusCode == 204) {
        msg("Classe supprimée");
        load();
      } else {
        final err = res.body.trim().isNotEmpty ? res.body.trim() : "Erreur ${res.statusCode}";
        msg(err, error: true);
      }
    } catch (e) {
      msg("Impossible de joindre le serveur", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage groups")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showForm(),
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : classes.isEmpty
              ? const Center(child: Text("Aucune classe"))
              : ListView.builder(
                  itemCount: classes.length,
                  itemBuilder: (context, i) {
                    final c = classes[i];
                    return ListTile(
                      leading: const Icon(Icons.groups, color: Colors.deepOrange),
                      title: Text(c.nomClass),
                      subtitle: Text("${c.nbreEtud} étudiant${c.nbreEtud > 1 ? 's' : ''}"),
                      onTap: () => showForm(classe: c),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => delete(c.codClass),
                      ),
                    );
                  },
                ),
    );
  }
}
