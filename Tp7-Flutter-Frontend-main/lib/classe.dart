class Classe {
  final int codClass;
  final String nomClass;
  final int nbreEtud;

  Classe({
    required this.codClass,
    required this.nomClass,
    required this.nbreEtud,
  });

  factory Classe.fromMap(Map<String, dynamic> m) => Classe(
        codClass: m['codClass'] is int
            ? m['codClass']
            : int.tryParse(m['codClass']?.toString() ?? '0') ?? 0,
        nomClass: (m['nomClass'] ?? '').toString(),
        nbreEtud: m['nbreEtud'] is int
            ? m['nbreEtud']
            : int.tryParse(m['nbreEtud']?.toString() ?? '0') ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'codClass': codClass,
        'nomClass': nomClass,
        'nbreEtud': nbreEtud,
      };
}
