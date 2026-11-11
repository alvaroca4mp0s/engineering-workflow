<!-- engineering-workflow:handoff v0.1.0 -->
<!--
  THIS FILE IS DISPOSABLE. It is a temporary operational artifact, not a
  durable source of truth. Durable decisions belong in ADRs/docs. Durable
  approvals belong in .engineering-workflow/APPROVALS.log (or a commit
  trailer), never only here. This file may be regenerated or discarded at
  any time — see methodology/OVERVIEW.md principle 7.
-->

# Handoff

- Generated at: 2026-11-11T03:03:23Z
- Stage: spec
- Risk: HIGH
- Git branch: feat/ew-gov-01a
- Git HEAD: b3554f6

## Note

Destinatario: Builder — Cierre QA de EW-GOV-01A y Brief / Especificación autorizada para ejecutar EW-GOV-01B.

=== 1. CIERRE DE EW-GOV-01A ===
- Dictamen Auditor QA independiente (EW-GOV-01A, Risk: HIGH): APROBADO (CLEAN REVIEW).
  - Findings ACCEPT: 0 | Findings HUMAN DECISION: 0 | Findings REJECT: 1 observación menor documentada (resumen de exit codes en docs/OPERATIONS.md L76-L78 ya cubierto por L108-L110).
- Evidencia VERIFY / BUILD reproducida: ./tests/run.sh => 10/10 PASS (exit 0), bash -n ... => exit 0, git diff --check => exit 0 en Bash 3.2.57 / Git 2.54.0 / jq 1.7.1.
- Commit de EW-GOV-01A: b3554f6ec206b165ee2b60d96930f9ea7d994093 en rama feat/ew-gov-01a (base main 8931ead).
- stash@{0} (INFORME.md) preservado intacto sin restaurar.

=== 2. BRIEF AUTORIZADO PARA EW-GOV-01B (Stage: SPEC -> IMPLEMENT -> VERIFY -> REVIEW, Risk: HIGH) ===
Título: Runner determinista de VERIFY, persistencia de evidencia y exposición CLI en despachador.

A. Objetivo:
Implementar la ejecución determinista de commands.verify declarado en .engineering-workflow/workflow.config.json, persistir evidencia estructurada del resultado y conectar su consulta con generate-handoff.sh, read-handoff.sh y el despachador bin/engineering-workflow, manteniendo 100% compatibilidad con Bash 3.2+, git y jq.

B. Alcance autorizado e interfaz:
1) Nuevo script ejecutable scripts/verify-project.sh <target-dir> (default '.'):
   - Valida que <target-dir> exista, sea un repositorio Git y que .engineering-workflow/workflow.config.json sea válido mediante ew_validate_contract (fail-closed exit 1).
   - Rechaza con exit 1 (fail-closed, sin ejecutar comando ni escribir evidencia PASS) si commands.verify contiene el placeholder REPLACE_ME (p. ej. cadena que contenga 'REPLACE_ME').
   - Ejecuta el comando declarado en commands.verify con directorio de trabajo <target-dir> (vía bash -c) y captura su exit code real sin abortar prematuramente por set -e.
   - Escribe/actualiza .engineering-workflow/VERIFY.json (de forma atómica vía archivo temporal en .engineering-workflow/ + mv) con un único objeto JSON validable con jq:
     * schema_version: '1'
     * verified_at: timestamp UTC ISO-8601 (%Y-%m-%dT%H:%M:%SZ)
     * git_head: commit resuelto actual (git rev-parse --verify HEAD o 'no-commits')
     * git_tree_dirty: boolean (true si git status --porcelain ignorando .engineering-workflow/VERIFY.json y .engineering-workflow/HANDOFF.md tiene cambios; false en caso contrario)
     * command: string exacto de commands.verify
     * exit_code: número entero con el código de salida real
     * status: 'PASS' si exit_code == 0, 'FAIL' si exit_code != 0
   - Devuelve como código de salida del script el mismo exit_code de commands.verify (0 si PASS, != 0 si FAIL; 1 en errores de preflight/contrato/REPLACE_ME).
   - Asegurar que .engineering-workflow/.gitignore no ignore VERIFY.json o bien documentar explícitamente su tratamiento (VERIFY.json o su lectura por handoff debe ser determinista; mantener compatibilidad con los 8 tests originales de init/idempotency/gitignore_merge: NO modificar templates/EW-GITIGNORE.template si ello rompe los 8 tests originales).

2) Integración consultiva con scripts/handoff/generate-handoff.sh y scripts/handoff/read-handoff.sh:
   - Restricción dura de compatibilidad: Los 8 tests originales (y los 2 de EW-GOV-01A) NO deben romperse. Dado que tests/test_handoff_cycle.sh y tests/test_handoff_controls.sh invocan generate-handoff.sh con --stage review/handoff y --risk CRITICAL sobre repositorios con el contrato template (REPLACE_ME) sin haber corrido verify-project.sh previamente, la comprobación en generate-handoff.sh y read-handoff.sh debe ser:
     * Consultiva (ew_log_warn en stderr, sin abortar exit 0) cuando --stage sea verify, review, document, handoff o commit y no exista .engineering-workflow/VERIFY.json válido con status=='PASS' y git_head coincidente con el HEAD actual (o cuando exista con status=='FAIL' o git_head desfasado), O BIEN
     * Soportar además un flag explícito --require-verify en generate-handoff.sh que sí aplique fail-closed (exit 1 antes de tocar APPROVALS.log, backups/ o HANDOFF.md) si no existe .engineering-workflow/VERIFY.json válido con status=='PASS', git_head igual al HEAD actual y git_tree_dirty==false.
   - En read-handoff.sh: si existe .engineering-workflow/VERIFY.json pero su status != 'PASS' o su git_head difiere del HEAD actual, emitir ew_log_warn consultivo en stderr (sin bloquear la lectura).

3) Exposición en despachador bin/engineering-workflow:
   - Añadir subcomandos:
     * engineering-workflow verify [target-dir] -> delega a scripts/verify-project.sh
     * engineering-workflow handoff generate <args...> -> delega a scripts/handoff/generate-handoff.sh
     * engineering-workflow handoff read [target-dir] -> delega a scripts/handoff/read-handoff.sh
     * Subcomando inválido de handoff (o sin subcomando) -> error descriptivo en stderr y exit 1.
   - Actualizar usage() en bin/engineering-workflow.

4) Pruebas y documentación:
   - Los 8 tests originales de la línea base deben permanecer SIN modificaciones.
   - Añadir nueva suite tests/test_verify_evidence.sh que pruebe:
     * Rechazo fail-closed de REPLACE_ME y de contratos inválidos/ausentes en verify-project.sh.
     * Ejecución de commands.verify con exit 0 -> genera VERIFY.json con status='PASS', exit_code=0, git_head correcto y git_tree_dirty correcto.
     * Ejecución de commands.verify con fallo (p. ej. 'exit 7') -> propaga exit code != 0 y registra VERIFY.json con status='FAIL' y exit_code=7.
     * Detección de evidencia ausente, FAIL, HEAD desfasado o árbol sucio en generate-handoff.sh (warning consultivo por defecto en etapas post-verify y bloqueo fail-closed con --require-verify sin tocar HANDOFF.md ni APPROVALS.log) y en read-handoff.sh.
     * Subcomandos bin/engineering-workflow verify y bin/engineering-workflow handoff generate|read.
   - Actualizar docs/OPERATIONS.md, docs/ENGINEERING-WORKFLOW-HANDBOOK.md y docs/MAINTENANCE.md reflejando sólo lo implementado y sus límites reales.

C. Restricciones operativas:
- No restaurar ni eliminar stash@{0} (INFORME.md).
- No hacer git commit, push ni merge: dejar los cambios de EW-GOV-01B en el árbol de trabajo sobre feat/ew-gov-01a y actualizar .engineering-workflow/HANDOFF.md en stage=review, risk=HIGH dirigido al Auditor QA.

## Git status at generation time

```
(clean)
```
