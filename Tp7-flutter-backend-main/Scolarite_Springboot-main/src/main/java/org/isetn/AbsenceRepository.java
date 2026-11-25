package org.isetn;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.rest.core.annotation.RepositoryRestResource;

@RepositoryRestResource(exported = false)
public interface AbsenceRepository extends JpaRepository<Absence, Integer> {
	List<Absence> findByEtudiantIdOrderByDateADesc(Integer etudiantId);

	boolean existsByCodMatAndEtudiantIdAndDateA(String codMat, Integer etudiantId, LocalDate dateA);

	Optional<Absence> findByCodMatAndEtudiantIdAndDateA(String codMat, Integer etudiantId, LocalDate dateA);

	void deleteByEtudiantId(Integer etudiantId);
}