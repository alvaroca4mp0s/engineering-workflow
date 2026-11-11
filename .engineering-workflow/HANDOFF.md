<!-- engineering-workflow:handoff v0.1.0 -->
<!--
  THIS FILE IS DISPOSABLE. It is a temporary operational artifact, not a
  durable source of truth. Durable decisions belong in ADRs/docs. Durable
  approvals belong in .engineering-workflow/APPROVALS.log (or a commit
  trailer), never only here. This file may be regenerated or discarded at
  any time — see methodology/OVERVIEW.md principle 7.
-->

# Handoff

- Generated at: 2026-11-11T15:40:40Z
- Stage: review
- Risk: HIGH
- Git branch: feat/ew-gov-01a
- Git HEAD: 53c0a0c

## Note

Destinatario: Auditor QA — EW-GOV-01B, IMPLEMENT y VERIFY completados; revisión independiente HIGH pendiente. No declarar cierre sin dictamen QA.

Baseline de esta sesión: feat/ew-gov-01a, HEAD 53c0a0c (árbol inicialmente limpio). Especificación autorizada: git show 53c0a0c:.engineering-workflow/HANDOFF.md, sección 2. EW-GOV-01A continúa cerrado en b3554f6 con CLEAN REVIEW. No se hicieron commits, push ni merge. stash@{0} (INFORME.md) preservado sin restaurar ni eliminar.

Diff: git diff -- README.md bin/engineering-workflow scripts/lib/common.sh scripts/handoff/generate-handoff.sh scripts/handoff/read-handoff.sh docs/OPERATIONS.md docs/ENGINEERING-WORKFLOW-HANDBOOK.md docs/MAINTENANCE.md .engineering-workflow/HANDOFF.md
Nuevos archivos NO incluidos en git diff normal: scripts/verify-project.sh (ejecutable), tests/test_verify_evidence.sh (ejecutable), .engineering-workflow/VERIFY.json (evidencia generada). Revisar con git diff --no-index -- /dev/null <archivo>; exit 1 significa diferencias. Los diez tests anteriores no se modificaron; git diff 53c0a0c -- tests/ debe quedar vacío mientras el nuevo test siga no versionado.

Implementación: runner preflight Git/contrato, rechazo REPLACE_ME/NUL, comando exacto vía bash -c en target con exit code propagado; resultado schema_version=1 escrito mediante mktemp local + mv atómico y limpieza de temporales. HEAD/dirty muestreados después del comando y antes del temporal. Dirty contempla todo el repo, con untracked individuales y exclusión solo de los dos snapshots en el target (más ignores normales); HEAD cambiado durante el comando fuerza dirty=true. No se alteró la plantilla gitignore.

Handoff: avisos consultivos en etapas verify/review/document/handoff/commit ante evidencia ausente/inválida/FAIL/stale/dirty. Reader avisa solo si existe evidencia problemática, conservando lectura legacy. --require-verify exige evidencia válida PASS HEAD actual y dirty=false, más árbol actual limpio, antes de APPROVALS.log/backups/HANDOFF. Dispatcher expone verify y handoff generate/read, con errores de subcomando descriptivos.

Compatibilidad y documentación: Bash 3.2+, Git y jq, sin dependencias nuevas ni estado/orquestación. OPERATIONS documenta esquema y límites; handbook y MAINTENANCE actualizados. README corregido mínimamente para no afirmar que la aprobación CRITICAL es el único gate mecánico. Documentado que commands.verify es código de confianza y puede escribir fuera de las rutas gestionadas por E-W; no es sandbox.

Pruebas reales: baseline ./tests/run.sh 10/10 exit 0; suite final 11/11 exit 0. bash tests/test_verify_evidence.sh exit 0. Build declarado bash -n bin/engineering-workflow scripts/*.sh scripts/handoff/*.sh scripts/lib/*.sh tests/*.sh tests/lib/*.sh exit 0. git diff --check exit 0. End-to-end ./bin/engineering-workflow verify . ejecutó ./tests/run.sh 11/11 y devolvió exit 0, generando VERIFY.json status=PASS, exit_code=0, git_tree_dirty=true. Esto NO es evidencia de árbol limpio: los cambios de implementación siguen sin commit por instrucción. El aviso al generar este handoff es esperado; --require-verify debe rechazar este árbol.

Entorno: Bash 3.2.57 arm64-apple-darwin26, Git 2.54.0 Apple, jq 1.7.1 Apple. Sin revalidación Linux en esta sesión.

Puntos críticos QA: comando exacto (quotes, pipes, saltos finales), cwd/default target; preflight sin ejecución ni publicación PASS; FAIL exit 7; JSON consistente y atómico, fallo mv preserva evidencia anterior y limpia temporal; datos manipulados/malformados; gate estricto sin append ni backup; evidencia ausente/stale/dirty y cambios posteriores; exclusiones de snapshots sin colapsar directorios untracked y alcance de Git en targets anidados; CLI directa e instalada por symlink. Autorrevisión de diff realizada; no cuenta como revisión independiente.

Riesgos residuales explícitos: evidencia mutable/no autenticada, sin historial ni logs stdout/stderr ni bloqueo concurrente. Atomicidad evita JSON parcial, no carreras ni garantiza fsync. Un error de preflight/IO puede dejar resultado anterior: atender exit code. No se compara fingerprint de contenido ni historial de comandos; ignores de Git y manipulación manual quedan fuera de la garantía. Modo consultivo no consulta dirty actual independientemente del flag; modo estricto sí. Ninguna aprobación autentica identidad humana ni se mecaniza profundidad de revisión.

Siguiente paso: Auditor QA inspecciona diff y archivos nuevos, reproduce verify/build/check y evalúa como HIGH; resolver findings según metodología. No commit/push/merge ni ampliación de alcance sin instrucción.

## Git status at generation time

```
 M README.md
 M bin/engineering-workflow
 M docs/ENGINEERING-WORKFLOW-HANDBOOK.md
 M docs/MAINTENANCE.md
 M docs/OPERATIONS.md
 M scripts/handoff/generate-handoff.sh
 M scripts/handoff/read-handoff.sh
 M scripts/lib/common.sh
?? .engineering-workflow/VERIFY.json
?? scripts/verify-project.sh
?? tests/test_verify_evidence.sh
```
