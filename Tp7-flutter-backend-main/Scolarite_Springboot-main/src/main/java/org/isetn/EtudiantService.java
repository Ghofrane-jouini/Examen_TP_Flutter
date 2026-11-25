package org.isetn;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class EtudiantService {

	@Autowired
	private EtudiantRepository etudiantRepository;
	@Autowired
	private ClasseRepository classeRepository;
	@Autowired
	private FormationRepository formationRepository;
	@Autowired
	private AbsenceRepository absenceRepository;
	@Autowired
	private NoteRepository noteRepository;

	private ResponseStatusException err(HttpStatus s, String m) {
		return new ResponseStatusException(s, m);
	}

	private void validateNames(Etudiant e) {
		if (e.getNom() == null || e.getNom().isBlank() || e.getPrenom() == null || e.getPrenom().isBlank()) {
			throw err(HttpStatus.BAD_REQUEST, "Le nom et le prénom sont obligatoires");
		}
	}

	private Classe resolveClasse(Etudiant e) {
		if (e.getClasse() == null || e.getClasse().getCodClass() == null) {
			throw err(HttpStatus.BAD_REQUEST, "La classe est obligatoire");
		}
		return classeRepository.findById(e.getClasse().getCodClass())
				.orElseThrow(() -> err(HttpStatus.BAD_REQUEST, "La classe indiquée n'existe pas"));
	}

	private Formation resolveFormation(Etudiant e) {
		if (e.getFormation() == null || e.getFormation().getId() == null) {
			return null;
		}
		return formationRepository.findById(e.getFormation().getId())
				.orElseThrow(() -> err(HttpStatus.BAD_REQUEST, "La formation indiquée n'existe pas"));
	}

	@Transactional
	public Etudiant create(Etudiant in) {
		validateNames(in);
		Classe classe = resolveClasse(in);

		Etudiant e = new Etudiant();
		e.setNom(in.getNom().trim());
		e.setPrenom(in.getPrenom().trim());
		e.setDateNais(in.getDateNais());
		e.setClasse(classe);
		e.setFormation(resolveFormation(in));

		Etudiant saved = etudiantRepository.save(e);
		recalc(classe.getCodClass());
		return saved;
	}

	@Transactional
	public Etudiant update(Integer id, Etudiant in) {
		Etudiant e = etudiantRepository.findById(id)
				.orElseThrow(() -> err(HttpStatus.NOT_FOUND, "Étudiant introuvable"));
		validateNames(in);
		Classe nouvelle = resolveClasse(in);
		Integer ancienne = e.getClasse() == null ? null : e.getClasse().getCodClass();

		e.setNom(in.getNom().trim());
		e.setPrenom(in.getPrenom().trim());
		if (in.getDateNais() != null) {
			e.setDateNais(in.getDateNais());
		}
		e.setClasse(nouvelle);
		Formation f = resolveFormation(in);
		if (f != null) {
			e.setFormation(f);
		}

		Etudiant saved = etudiantRepository.save(e);
		recalc(nouvelle.getCodClass());
		if (ancienne != null && !ancienne.equals(nouvelle.getCodClass())) {
			recalc(ancienne);
		}
		return saved;
	}

	@Transactional
	public void delete(Integer id) {
		Etudiant e = etudiantRepository.findById(id)
				.orElseThrow(() -> err(HttpStatus.NOT_FOUND, "Étudiant introuvable"));
		Integer cod = e.getClasse() == null ? null : e.getClasse().getCodClass();

		absenceRepository.deleteByEtudiantId(id);
		noteRepository.deleteByEtudiantId(id);
		etudiantRepository.delete(e);
		etudiantRepository.flush();

		if (cod != null) {
			recalc(cod);
		}
	}

	/** nbreEtud = nombre réel d'étudiants en base (source de vérité unique). */
	public void recalc(Integer codClass) {
		classeRepository.findById(codClass).ifPresent(c -> {
			c.setNbreEtud((int) etudiantRepository.countByClasseCodClass(codClass));
			classeRepository.save(c);
		});
	}

	@Transactional
	public void resyncAll() {
		for (Classe c : classeRepository.findAll()) {
			recalc(c.getCodClass());
		}
	}
}
