package org.isetn;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.rest.core.annotation.RepositoryRestResource;

@RepositoryRestResource(exported = false)
public interface ClassMatRepository extends JpaRepository<ClassMat, Integer> {
    List<ClassMat> findByCodClass(Integer codClass);

    Optional<ClassMat> findByCodClassAndCodMat(Integer codClass, String codMat);
}