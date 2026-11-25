package org.isetn;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** Saisie et affichage PAR CLASSE et PAR MATIÈRE : absences (à une date) et notes. */
@CrossOrigin("*")
@RestController
public class ClasseMatiereController {

    public record AbsenceLigne(Integer etudiantId, String nom, String prenom, Double nha) {
    }

    public record NoteLigne(Integer etudiantId, String nom, String prenom, Double tp1, Double tp2, Double ds,
                            Double dc) {
    }

    @Autowired
    private ClasseRepository classeRepository;
    @Autowired
    private MatiereRepository matiereRepository;
    @Autowired
    private EtudiantRepository etudiantRepository;
    @Autowired
    private AbsenceRepository absenceRepository;
    @Autowired
    private NoteRepository noteRepository;

    private ResponseStatusException err(HttpStatus s, String m) {
        return new ResponseStatusException(s, m);
    }

    /** Étudiants de la classe triés par nom/prénom ; vérifie que classe et matière existent. */
    private List<Etudiant> etudiantsDe(Integer codClass, String codMat) {
        if (!classeRepository.existsById(codClass)) {
            throw err(HttpStatus.NOT_FOUND, "Classe introuvable");
        }
        if (!matiereRepository.existsById(codMat)) {
            throw err(HttpStatus.NOT_FOUND, "Matière introuvable");
        }
        List<Etudiant> l = new ArrayList<>(etudiantRepository.findByClasseCodClass(codClass));
        l.sort(Comparator.comparing((Etudiant e) -> e.getNom() == null ? "" : e.getNom().toLowerCase())
                .thenComparing(e -> e.getPrenom() == null ? "" : e.getPrenom().toLowerCase()));
        return l;
    }

    private Map<Integer, Etudiant> index(List<Etudiant> l) {
        Map<Integer, Etudiant> m = new HashMap<>();
        for (Etudiant e : l) {
            m.put(e.getId(), e);
        }
        return m;
    }

    // ======================= ABSENCES =======================

    @GetMapping("/absences/classe/{codClass}/matiere/{codMat}")
    public List<AbsenceLigne> absences(@PathVariable("codClass") Integer codClass,
                                       @PathVariable("codMat") String codMat,
                                       @RequestParam("date") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return lignesAbsences(etudiantsDe(codClass, codMat), codMat, date);
    }

    private List<AbsenceLigne> lignesAbsences(List<Etudiant> etudiants, String codMat, LocalDate date) {
        List<AbsenceLigne> res = new ArrayList<>();
        for (Etudiant e : etudiants) {
            Double nha = absenceRepository.findByCodMatAndEtudiantIdAndDateA(codMat, e.getId(), date)
                    .map(Absence::getNha).orElse(null);
            res.add(new AbsenceLigne(e.getId(), e.getNom(), e.getPrenom(), nha));
        }
        return res;
    }

    @PutMapping("/absences/classe/{codClass}/matiere/{codMat}")
    @Transactional
    public List<AbsenceLigne> saveAbsences(@PathVariable("codClass") Integer codClass,
                                           @PathVariable("codMat") String codMat,
                                           @RequestParam("date") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                           @RequestBody List<AbsenceLigne> lignes) {
        List<Etudiant> etudiants = etudiantsDe(codClass, codMat);
        Map<Integer, Etudiant> byId = index(etudiants);

        for (AbsenceLigne l : lignes) {
            if (l.etudiantId() == null || !byId.containsKey(l.etudiantId())) {
                throw err(HttpStatus.BAD_REQUEST, "Un étudiant n'appartient pas à cette classe");
            }
            if (l.nha() != null && (l.nha().isNaN() || l.nha() < 0)) {
                throw err(HttpStatus.BAD_REQUEST, "NHA invalide pour " + byId.get(l.etudiantId()).getNom());
            }
        }
        for (AbsenceLigne l : lignes) {
            var existante = absenceRepository.findByCodMatAndEtudiantIdAndDateA(codMat, l.etudiantId(), date);
            if (l.nha() == null || l.nha() == 0) {
                existante.ifPresent(absenceRepository::delete); // 0 ou vide = pas d'absence
            } else {
                Absence a = existante.orElseGet(() -> {
                    Absence x = new Absence();
                    x.setCodMat(codMat);
                    x.setEtudiantId(l.etudiantId());
                    x.setDateA(date);
                    return x;
                });
                a.setNha(l.nha());
                absenceRepository.save(a);
            }
        }
        return lignesAbsences(etudiants, codMat, date);
    }

    // ======================= NOTES =======================

    @GetMapping("/notes/classe/{codClass}/matiere/{codMat}")
    public List<NoteLigne> notes(@PathVariable("codClass") Integer codClass, @PathVariable("codMat") String codMat) {
        return lignesNotes(etudiantsDe(codClass, codMat), codMat);
    }

    private List<NoteLigne> lignesNotes(List<Etudiant> etudiants, String codMat) {
        List<NoteLigne> res = new ArrayList<>();
        for (Etudiant e : etudiants) {
            NoteLigne l = noteRepository.findByEtudiantIdAndCodMat(e.getId(), codMat)
                    .map(n -> new NoteLigne(e.getId(), e.getNom(), e.getPrenom(), n.getTp1(), n.getTp2(), n.getDs(),
                            n.getDc()))
                    .orElse(new NoteLigne(e.getId(), e.getNom(), e.getPrenom(), null, null, null, null));
            res.add(l);
        }
        return res;
    }

    @PutMapping("/notes/classe/{codClass}/matiere/{codMat}")
    @Transactional
    public List<NoteLigne> saveNotes(@PathVariable("codClass") Integer codClass,
                                     @PathVariable("codMat") String codMat, @RequestBody List<NoteLigne> lignes) {
        List<Etudiant> etudiants = etudiantsDe(codClass, codMat);
        Map<Integer, Etudiant> byId = index(etudiants);

        for (NoteLigne l : lignes) {
            if (l.etudiantId() == null || !byId.containsKey(l.etudiantId())) {
                throw err(HttpStatus.BAD_REQUEST, "Un étudiant n'appartient pas à cette classe");
            }
            String nom = byId.get(l.etudiantId()).getNom();
            check(l.tp1(), "TP1", nom);
            check(l.tp2(), "TP2", nom);
            check(l.ds(), "DS", nom);
            check(l.dc(), "DC", nom);
        }
        for (NoteLigne l : lignes) {
            var existante = noteRepository.findByEtudiantIdAndCodMat(l.etudiantId(), codMat);
            boolean vide = l.tp1() == null && l.tp2() == null && l.ds() == null && l.dc() == null;
            if (vide) {
                existante.ifPresent(noteRepository::delete);
            } else {
                Note n = existante.orElseGet(() -> {
                    Note x = new Note();
                    x.setEtudiantId(l.etudiantId());
                    x.setCodMat(codMat);
                    return x;
                });
                n.setTp1(l.tp1());
                n.setTp2(l.tp2());
                n.setDs(l.ds());
                n.setDc(l.dc());
                noteRepository.save(n);
            }
        }
        return lignesNotes(etudiants, codMat);
    }

    private void check(Double v, String champ, String nom) {
        if (v != null && (v.isNaN() || v < 0 || v > 20)) {
            throw err(HttpStatus.BAD_REQUEST,
                    "Note " + champ + " invalide pour " + nom + " (doit être entre 0 et 20)");
        }
    }
}