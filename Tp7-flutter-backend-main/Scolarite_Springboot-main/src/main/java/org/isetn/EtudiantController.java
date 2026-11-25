package org.isetn;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@CrossOrigin("*")
@RestController
public class EtudiantController {
	@Autowired
	private EtudiantRepository etudiantRepository;
	@Autowired
	private EtudiantService etudiantService;

	@GetMapping("/etudiants")
	public List<Etudiant> all() {
		return etudiantRepository.findAll();
	}

	@GetMapping("/etudiants/classe/{codClass}")
	public List<Etudiant> byClasse(@PathVariable Integer codClass) {
		return etudiantRepository.findByClasseCodClass(codClass);
	}

	@PostMapping("/etudiants")
	public Etudiant save(@RequestBody Etudiant e) {
		return etudiantService.create(e);
	}

	@PutMapping("/etudiants/{id}")
	public Etudiant update(@PathVariable Integer id, @RequestBody Etudiant e) {
		return etudiantService.update(id, e);
	}

	@DeleteMapping("/etudiants/{id}")
	public void delete(@PathVariable Integer id) {
		etudiantService.delete(id);
	}
}
