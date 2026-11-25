import 'classe.dart';

class Etudiant {
  final int id;
  final String nom;
  final String prenom;
  final String? dateNais;
  final Classe? classe;

  Etudiant({
    required this.id,
    required this.nom,
    required this.prenom,
    this.dateNais,
    this.classe,
  });

  factory Etudiant.fromMap(Map<String, dynamic> m) => Etudiant(
        id: m['id'] is int
            ? m['id']
            : int.tryParse(m['id']?.toString() ?? '0') ?? 0,
        nom: (m['nom'] ?? '').toString(),
        prenom: (m['prenom'] ?? '').toString(),
        dateNais: m['dateNais'] as String?,
        classe: m['classe'] is Map<String, dynamic>
            ? Classe.fromMap(m['classe'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'prenom': prenom,
        'dateNais': dateNais,
        if (classe != null) 'classe': classe!.toMap(),
      };
}
