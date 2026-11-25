package org.isetn;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** Moyennes générales d'une classe (toutes matières, pondérées par les coefficients de ClassMat). */
@CrossOrigin("*")
@RestController
public class MoyenneController {

    public record MatiereCoef(String codMat, String intMat, Double coef) {
    }

    public record CoefInput(String codMat, Double coef) {
    }

    public record DetailMatiere(String codMat, Double moyenne, Double coef) {
    }

    public record EtudiantMoyenne(Integer etudiantId, String nom, String prenom, Double moyenne,
                                  List<DetailMatiere> details) {
    }

    public record MoyennesClasse(Integer codClass, String nomClass, String departement, Double moyenneClasse,
                                 List<EtudiantMoyenne> etudiants) {
    }

    @Autowired
    private ClasseRepository classeRepository;
    @Autowired
    private MatiereRepository matiereRepository;
    @Autowired
    private EtudiantRepository etudiantRepository;
    @Autowired
    private NoteRepository noteRepository;
    @Autowired
    private ClassMatRepository classMatRepository;

    private ResponseStatusException err(HttpStatus s, String m) {
        return new ResponseStatusException(s, m);
    }

    private Classe classe(Integer codClass) {
        return classeRepository.findById(codClass).orElseThrow(() -> err(HttpStatus.NOT_FOUND, "Classe introuvable"));
    }

    private Map<String, Double> coefsDe(Integer codClass) {
        Map<String, Double> m = new HashMap<>();
        for (ClassMat cm : classMatRepository.findByCodClass(codClass)) {
            m.put(cm.getCodMat(), cm.getCoef());
        }
        return m;
    }

    // ======================= COEFFICIENTS =======================

    /** Toutes les matières avec leur coefficient dans la classe (1 par défaut). */
    @GetMapping("/classmat/classe/{codClass}")
    public List<MatiereCoef> coefficients(@PathVariable("codClass") Integer codClass) {
        classe(codClass);
        Map<String, Double> coefs = coefsDe(codClass);
        List<MatiereCoef> res = new ArrayList<>();
        for (Matiere m : matiereRepository.findAll()) {
            res.add(new MatiereCoef(m.getCodMat(), m.getIntMat(), coefs.getOrDefault(m.getCodMat(), 1.0)));
        }
        res.sort(Comparator.comparing(MatiereCoef::codMat));
        return res;
    }

    @PutMapping("/classmat/classe/{codClass}")
    @Transactional
    public List<MatiereCoef> saveCoefficients(@PathVariable("codClass") Integer codClass,
                                              @RequestBody List<CoefInput> lignes) {
        classe(codClass);
        Set<String> vus = new HashSet<>();
        for (CoefInput l : lignes) {
            if (l.codMat() == null || !matiereRepository.existsById(l.codMat())) {
                throw err(HttpStatus.BAD_REQUEST, "Matière inexistante : " + l.codMat());
            }
            if (!vus.add(l.codMat())) {
                throw err(HttpStatus.BAD_REQUEST, "Matière en double : " + l.codMat());
            }
            if (l.coef() == null || l.coef().isNaN() || l.coef() <= 0 || l.coef() > 100) {
                throw err(HttpStatus.BAD_REQUEST, "Coefficient invalide pour " + l.codMat() + " (doit être > 0)");
            }
        }
        for (CoefInput l : lignes) {
            ClassMat cm = classMatRepository.findByCodClassAndCodMat(codClass, l.codMat()).orElseGet(() -> {
                ClassMat x = new ClassMat();
                x.setCodClass(codClass);
                x.setCodMat(l.codMat());
                return x;
            });
            cm.setCoef(l.coef());
            classMatRepository.save(cm);
        }
        return coefficients(codClass);
    }

    // ======================= MOYENNES =======================

    /**
     * Moyenne d'une matière = (TP1+TP2+DS+DC)/4 si les 4 notes sont saisies. Moyenne générale = somme(moyenne *
     * coef) / somme(coef) sur les matières complètes. Null si aucune matière complète.
     */
    @GetMapping("/moyennes/classe/{codClass}")
    public MoyennesClasse moyennes(@PathVariable("codClass") Integer codClass) {
        Classe c = classe(codClass);
        Map<String, Double> coefs = coefsDe(codClass);

        List<Etudiant> etudiants = new ArrayList<>(etudiantRepository.findByClasseCodClass(codClass));
        etudiants.sort(Comparator.comparing((Etudiant e) -> e.getNom() == null ? "" : e.getNom().toLowerCase())
                .thenComparing(e -> e.getPrenom() == null ? "" : e.getPrenom().toLowerCase()));

        List<EtudiantMoyenne> lignes = new ArrayList<>();
        double sommeClasse = 0;
        int nbClasse = 0;

        for (Etudiant e : etudiants) {
            double somme = 0;
            double sommeCoef = 0;
            List<DetailMatiere> details = new ArrayList<>();

            for (Note n : noteRepository.findByEtudiantIdOrderByCodMat(e.getId())) {
                if (n.getTp1() == null || n.getTp2() == null || n.getDs() == null || n.getDc() == null) {
                    continue; // matière incomplète : ignorée
                }
                double moyMat = (n.getTp1() + n.getTp2() + n.getDs() + n.getDc()) / 4.0;
                double coef = coefs.getOrDefault(n.getCodMat(), 1.0);
                somme += moyMat * coef;
                sommeCoef += coef;
                details.add(new DetailMatiere(n.getCodMat(), moyMat, coef));
            }

            Double moyenne = null;
            if (sommeCoef > 0) {
                moyenne = somme / sommeCoef;
                sommeClasse += moyenne;
                nbClasse++;
            }
            lignes.add(new EtudiantMoyenne(e.getId(), e.getNom(), e.getPrenom(), moyenne, details));
        }

        Double moyenneClasse = nbClasse > 0 ? Double.valueOf(sommeClasse / nbClasse) : null;
        return new MoyennesClasse(c.getCodClass(), c.getNomClass(), c.getDepartement(), moyenneClasse, lignes);
    }
}