package org.isetn;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Entity
public class Matiere {
	@Id
	private String codMat;
	private String intMat;
	private String description;
	/** Charge horaire semestrielle (CHSM), en heures. */
	private Integer chsm;
}