package org.isetn;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@CrossOrigin("*")
@RestController
public class AbsenceController {

	@Autowired
	private AbsenceRepository absenceRepository;
	@Autowired
	private MatiereRepository matiereRepository;
	@Autowired
	private EtudiantRepository etudiantRepository;

	@GetMapping("/matieres")
	public List<Matiere> matieres() {
		return matiereRepository.findAll();
	}

	@GetMapping("/absences/etudiant/{id}")
	public List<Absence> byEtudiant(@PathVariable Integer id) {
		return absenceRepository.findByEtudiantIdOrderByDateADesc(id);
	}

	@PostMapping("/absences")
	public Absence add(@RequestBody Absence a) {
		if (a.getEtudiantId() == null || !etudiantRepository.existsById(a.getEtudiantId())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Étudiant inexistant");
		}
		if (a.getCodMat() == null || !matiereRepository.existsById(a.getCodMat())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Matière inexistante");
		}
		if (a.getDateA() == null) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La date est obligatoire");
		}
		if (a.getNha() == null || a.getNha() <= 0) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Le nombre d'heures doit être supérieur à 0");
		}
		if (absenceRepository.existsByCodMatAndEtudiantIdAndDateA(a.getCodMat(), a.getEtudiantId(), a.getDateA())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Cette absence existe déjà (même matière et même date)");
		}
		a.setId(null);
		return absenceRepository.save(a);
	}

	@DeleteMapping("/absences/{id}")
	public void delete(@PathVariable Integer id) {
		if (!absenceRepository.existsById(id)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Absence introuvable");
		}
		absenceRepository.deleteById(id);
	}
}
