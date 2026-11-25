package org.isetn;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@CrossOrigin("*")
@RestController
public class ClasseController {
	@Autowired
	private ClasseRepository classeRepository;
	@Autowired
	private EtudiantRepository etudiantRepository;

	private void checkNom(Classe c) {
		if (c.getNomClass() == null || c.getNomClass().isBlank()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Le nom de la classe est obligatoire");
		}
	}

	@GetMapping("/classes")
	public List<Classe> all() {
		return classeRepository.findAll();
	}

	@PostMapping("/classes")
	public Classe save(@RequestBody Classe c) {
		checkNom(c);
		Classe n = new Classe();
		n.setNomClass(c.getNomClass().trim());
		n.setNbreEtud(0); // l'effectif est calculé par le serveur
		if (c.getDepartement() != null && !c.getDepartement().isBlank()) {
			n.setDepartement(c.getDepartement().trim());
		}
		return classeRepository.save(n);
	}

	@PutMapping("/classes/{id}")
	public Classe update(@PathVariable Integer id, @RequestBody Classe c) {
		checkNom(c);
		Classe existing = classeRepository.findById(id)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Classe introuvable"));
		existing.setNomClass(c.getNomClass().trim()); // nbreEtud du client ignoré
		if (c.getDepartement() != null && !c.getDepartement().isBlank()) {
			existing.setDepartement(c.getDepartement().trim());
		}
		return classeRepository.save(existing);
	}

	@DeleteMapping("/classes/{id}")
	public void delete(@PathVariable Integer id) {
		Classe existing = classeRepository.findById(id)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Classe introuvable"));
		long n = etudiantRepository.countByClasseCodClass(id);
		if (n > 0) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Impossible de supprimer la classe " + existing.getNomClass() + " : elle contient " + n
							+ " étudiant(s)");
		}
		classeRepository.deleteById(id);
	}
}