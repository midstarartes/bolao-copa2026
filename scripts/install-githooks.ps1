$ErrorActionPreference = 'Stop'

git config core.hooksPath .githooks

Write-Host ""
Write-Host "Hooks do projeto ativados para este PC." -ForegroundColor Green
Write-Host "Configuracao aplicada: git config core.hooksPath .githooks"
Write-Host ""
Write-Host "Antes de cada commit, o AGENTS.md deve estar atualizado e incluido no commit."
Write-Host ""
