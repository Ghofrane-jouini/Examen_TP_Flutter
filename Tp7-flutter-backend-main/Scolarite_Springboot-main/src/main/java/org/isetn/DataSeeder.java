package org.isetn;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

/** Au démarrage : matières par défaut, CHSM, département par défaut, resynchronisation des effectifs. */
@Component
public class DataSeeder implements CommandLineRunner {

	@Autowired
	private MatiereRepository matiereRepository;
	@Autowired
	private ClasseRepository classeRepository;
	@Autowired
	private EtudiantService etudiantService;

	@Override
	public void run(String... args) {
		if (matiereRepository.count() == 0) {
			matiereRepository.save(new Matiere("AFCP", "Framework cross-platform", null, 45));
			matiereRepository.save(new Matiere("MOB", "Développement mobile", null, 45));
			matiereRepository.save(new Matiere("SOA", "Architecture orientée services", null, 45));
		}
		// CHSM par défaut = 45 h pour les matières qui n'en ont pas encore
		for (Matiere m : matiereRepository.findAll()) {
			if (m.getChsm() == null) {
				m.setChsm(45);
				matiereRepository.save(m);
			}
		}
		// Département par défaut : les classes DSI* appartiennent au département TI
		for (Classe c : classeRepository.findAll()) {
			if (c.getDepartement() == null && c.getNomClass() != null
					&& c.getNomClass().toUpperCase().startsWith("DSI")) {
				c.setDepartement("TI");
				classeRepository.save(c);
			}
		}
		etudiantService.resyncAll();
	}
}