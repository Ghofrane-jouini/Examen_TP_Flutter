package org.isetn;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Vue globale des absences : regroupées PAR MATIÈRE, toutes classes confondues. */
@CrossOrigin("*")
@RestController
public class AbsenceParMatiereController {

    public record AbsenceDetail(Integer id, Integer etudiantId, String nom, String prenom, String nomClass,
                                LocalDate dateA, Double nha) {
    }

    public record MatiereAbsences(String codMat, String intMat, Integer chsm, double totalNha,
                                  List<AbsenceDetail> absences) {
    }

    public record TopMatiere(String codMat, String intMat, double totalNha) {
    }

    @Autowired
    private AbsenceRepository absenceRepository;
    @Autowired
    private MatiereRepository matiereRepository;
    @Autowired
    private EtudiantRepository etudiantRepository;

    /** Toutes les matières, chacune avec TOUTES ses absences (toutes classes), triées par total NHA décroissant. */
    @GetMapping("/absences/par-matiere")
    public List<MatiereAbsences> parMatiere() {
        Map<Integer, Etudiant> etudiants = etudiantRepository.findAll().stream()
                .collect(Collectors.toMap(Etudiant::getId, e -> e));
        Map<String, List<Absence>> parMat = absenceRepository.findAll().stream()
                .collect(Collectors.groupingBy(Absence::getCodMat));

        List<MatiereAbsences> res = new ArrayList<>();
        for (Matiere m : matiereRepository.findAll()) {
            List<AbsenceDetail> details = parMat.getOrDefault(m.getCodMat(), List.of()).stream()
                    .sorted((a, b) -> b.getDateA().compareTo(a.getDateA()))
                    .map(a -> {
                        Etudiant e = etudiants.get(a.getEtudiantId());
                        String classe = (e != null && e.getClasse() != null) ? e.getClasse().getNomClass() : null;
                        return new AbsenceDetail(a.getId(), a.getEtudiantId(), e == null ? null : e.getNom(),
                                e == null ? null : e.getPrenom(), classe, a.getDateA(), a.getNha());
                    }).toList();
            double total = details.stream().mapToDouble(d -> d.nha() == null ? 0 : d.nha()).sum();
            res.add(new MatiereAbsences(m.getCodMat(), m.getIntMat(), m.getChsm(), total, details));
        }
        res.sort(Comparator.comparingDouble(MatiereAbsences::totalNha).reversed());
        return res;
    }

    /** Les N matières (3 par défaut) avec le plus d'heures d'absence cumulées, toutes classes confondues. */
    @GetMapping("/absences/top-matieres")
    public List<TopMatiere> top(@RequestParam(name = "limit", defaultValue = "3") int limit) {
        return parMatiere().stream().filter(m -> m.totalNha() > 0).limit(Math.max(limit, 1))
                .map(m -> new TopMatiere(m.codMat(), m.intMat(), m.totalNha())).toList();
    }
}