package org.isetn;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.rest.core.annotation.RepositoryRestResource;

@RepositoryRestResource(exported = false)
public interface NoteRepository extends JpaRepository<Note, Integer> {
	List<Note> findByEtudiantIdOrderByCodMat(Integer etudiantId);

	Optional<Note> findByEtudiantIdAndCodMat(Integer etudiantId, String codMat);

	void deleteByEtudiantId(Integer etudiantId);
}
