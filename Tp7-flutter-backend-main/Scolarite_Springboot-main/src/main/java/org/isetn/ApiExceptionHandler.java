package org.isetn;

import java.nio.charset.StandardCharsets;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

/** Toutes les erreurs métier sont renvoyées en TEXTE BRUT (UTF-8) avec le bon statut HTTP. */
@RestControllerAdvice
public class ApiExceptionHandler {

	private static final MediaType TEXT_UTF8 = new MediaType("text", "plain", StandardCharsets.UTF_8);

	@ExceptionHandler(ResponseStatusException.class)
	public ResponseEntity<String> status(ResponseStatusException ex) {
		String msg = ex.getReason() == null ? "Erreur" : ex.getReason();
		return ResponseEntity.status(ex.getStatusCode()).contentType(TEXT_UTF8).body(msg);
	}

	@ExceptionHandler(HttpMessageNotReadableException.class)
	public ResponseEntity<String> unreadable(HttpMessageNotReadableException ex) {
		return ResponseEntity.badRequest().contentType(TEXT_UTF8).body("Corps de la requête invalide");
	}

	@ExceptionHandler(DataIntegrityViolationException.class)
	public ResponseEntity<String> integrity(DataIntegrityViolationException ex) {
		return ResponseEntity.status(409).contentType(TEXT_UTF8)
				.body("Opération impossible : doublon ou données liées");
	}
}
