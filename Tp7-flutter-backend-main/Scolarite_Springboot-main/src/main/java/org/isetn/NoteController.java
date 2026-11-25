package org.isetn;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@CrossOrigin("*")
@RestController
public class NoteController {

	@Autowired
	private NoteRepository noteRepository;
	@Autowired
	private MatiereRepository matiereRepository;
	@Autowired
	private EtudiantRepository etudiantRepository;

	@GetMapping("/notes/etudiant/{id}")
	public List<Note> get(@PathVariable Integer id) {
		if (!etudiantRepository.existsById(id)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Étudiant introuvable");
		}
		return noteRepository.findByEtudiantIdOrderByCodMat(id);
	}

	@PutMapping("/notes/etudiant/{id}")
	@Transactional
	public List<Note> save(@PathVariable Integer id, @RequestBody List<Note> lignes) {
		if (!etudiantRepository.existsById(id)) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Étudiant inexistant");
		}
		// 1) validation complète avant toute écriture
		Set<String> vus = new HashSet<>();
		for (Note l : lignes) {
			if (l.getCodMat() == null || !matiereRepository.existsById(l.getCodMat())) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Matière inexistante : " + l.getCodMat());
			}
			if (!vus.add(l.getCodMat())) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Matière en double : " + l.getCodMat());
			}
			check(l.getTp1(), "TP1", l.getCodMat());
			check(l.getTp2(), "TP2", l.getCodMat());
			check(l.getDs(), "DS", l.getCodMat());
			check(l.getDc(), "DC", l.getCodMat());
		}
		// 2) upsert
		for (Note l : lignes) {
			Note n = noteRepository.findByEtudiantIdAndCodMat(id, l.getCodMat()).orElseGet(() -> {
				Note x = new Note();
				x.setEtudiantId(id);
				x.setCodMat(l.getCodMat());
				return x;
			});
			n.setTp1(l.getTp1());
			n.setTp2(l.getTp2());
			n.setDs(l.getDs());
			n.setDc(l.getDc());
			noteRepository.save(n);
		}
		return noteRepository.findByEtudiantIdOrderByCodMat(id);
	}

	private void check(Double v, String nom, String codMat) {
		if (v != null && (v.isNaN() || v < 0 || v > 20)) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"Note " + nom + " invalide pour " + codMat + " (doit être entre 0 et 20)");
		}
	}
}
