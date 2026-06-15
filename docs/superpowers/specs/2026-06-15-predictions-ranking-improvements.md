# Spec: Improvements & Bug Fixes — Predictions + Ranking

**Data:** 2026-06-15  
**Status:** Aprovado pelo usuário

---

## Contexto

App em produção com 4 jogadores. Melhorias identificadas em usabilidade e dois bugs críticos de comportamento.

---

## 1. Tela de Palpites — Palpite em Destaque

**Arquivo:** `lib/features/predictions/views/predictions_screen.dart`

### Comportamento atual
A linha do palpite é texto cinza pequeno: `"Palpite: 2 × 1"` com `fontSize: 13, color: textSecondary`.

### Comportamento novo
Substituir a linha por uma row com três elementos:
- Ícone ⚽ (14px, textSecondary)
- Label `"Meu palpite:"` (11px, textSecondary)
- Badge laranja com o placar: fundo `#fff3e0`, borda `#f57c00`, texto `#e65100`, `fontSize: 15`, bold — ex: `"2 × 1"`
- Badge de pontos à direita (já existente — manter)

Para jogos não encerrados e sem pontos: mostrar badge laranja do placar + texto "Aguardando" no lugar do badge de pontos (comportamento existente mantido).

---

## 2. Tela de Palpites — Filtros e Ordenação

**Arquivos:** `lib/features/predictions/views/predictions_screen.dart`, `lib/features/predictions/viewmodels/predictions_viewmodel.dart`

### Comportamento atual
Lista agrupada por stage/fase, sem filtro, sem controle de ordenação. Encerrados ficam misturados com agendados.

### Comportamento novo

**Agrupamento padrão:** Dois grupos separados:
- `"📅 Próximos"` — status SCHEDULED ou LIVE, ordenados por data crescente (mais próximo primeiro)
- `"✅ Encerrados"` — status FINISHED, ordenados por data decrescente por padrão (mais recente primeiro)

**Chips de filtro** abaixo da AppBar (scroll horizontal):
- `Todos` (padrão) / `Agendados` / `Encerrados`
- Ao selecionar "Agendados" ou "Encerrados", oculta o outro grupo

**Botão ↑↓ na AppBar:** inverte a ordenação dos encerrados (mais antigos ↔ mais recentes primeiro). Ícone `Icons.sort`.

**Estado do filtro:** `StateProvider` local na tela (sem persistência), resetado ao sair.

---

## 3. Tela de Palpites — Explicação de Pontos Inline

**Arquivo:** `lib/features/predictions/views/predictions_screen.dart`

### Comportamento atual
Card de palpite encerrado não é clicável; não há explicação de como os pontos foram calculados.

### Comportamento novo
- Card encerrado com pontos calculados (`pts != null`) se torna clicável via `GestureDetector` / `InkWell`
- Ao tocar, o card **expande** revelando uma seção inline (sem popup)
- Tocar de novo recolhe (toggle via `StatefulWidget` ou `StateProvider` com o id do card expandido)

**Conteúdo da seção expandida:**
```
Como ganhei estes pontos
✅  Resultado certo (vitória/empate/derrota)     +5
✅  Placar do visitante correto (N)               +2
❌  Placar do mandante errado                     +0
```

**Lógica de cálculo local** (sem chamada extra ao backend):

Regras (mesmas do backend):
| Condição | Pontos |
|----------|--------|
| Placar exato (ambos corretos) | +10 |
| Resultado certo + exatamente 1 placar correto | +7 |
| Só resultado certo | +5 |
| Resultado errado | 0 |

Algoritmo para derivar o breakdown:
1. `resultCorrect` = `sign(predHome - predAway) == sign(scoreHome - scoreAway)`
2. `homeCorrect` = `predHome == scoreHome`
3. `awayCorrect` = `predAway == scoreAway`
4. Casos:
   - `!resultCorrect` → 0 pts, mostrar só ❌ Resultado errado
   - `resultCorrect && homeCorrect && awayCorrect` → +10, mostrar ✅ Placar exato
   - `resultCorrect && (homeCorrect || awayCorrect)` → +7, mostrar ✅ Resultado certo +5 / ✅ placar certo +2 / ❌ placar errado
   - `resultCorrect && !homeCorrect && !awayCorrect` → +5, mostrar ✅ Resultado certo +5 / ❌ dois placares errados

Exemplos de display:
```
// +7 pts: Suécia 5×1, palpite 2×1
✅  Resultado certo (vitória mandante)   +5
✅  Placar do visitante correto (1)       +2
❌  Placar do mandante errado (2 ≠ 5)    +0

// +10 pts: placar exato
✅  Placar exato! (2 × 1 = 2 × 1)       +10

// +5 pts
✅  Resultado certo (empate)             +5
❌  Placar do mandante errado            +0
❌  Placar do visitante errado           +0
```

A seção só aparece quando `pts != null` e `isFinished == true`.

---

## 4. Tela de Ranking — Mostrar Todos os Jogadores

**Arquivos:** `lib/features/ranking/viewmodels/ranking_viewmodel.dart`, backend `src/application/use-cases/GetRanking*`

### Comportamento atual
Ranking retorna apenas usuários que pontuaram (JOIN em predictions com pontos > 0).

### Comportamento novo
- Backend: retornar todos os usuários com role `MEMBER` ou `ADMIN`, mesmo com 0 palpites e 0 pontos
- Frontend: linha com `0 pts` e `0 palpites` exibida normalmente
- Posição calculada corretamente com empates pela regra de desempate existente

---

## 5. Tela de Ranking — Contagem de Palpites

**Arquivo:** `lib/features/ranking/views/ranking_screen.dart`

O model `RankingEntry` já possui `matchesPredicted`. Exibir abaixo do nome como sub-linha:
```
Gerson           87 pts
12 palpites
```
Fonte: 11px, `textSecondary`.

---

## 6. Tela de Ranking — Cards Redesenhados

**Arquivo:** `lib/features/ranking/views/ranking_screen.dart`

### Top 3 (posições 1, 2, 3)
- Borda esquerda: 5px sólida — 1° `#FFD700`, 2° `#B0BEC5`, 3° `#BF8C60`
- Fundo: gradiente sutil — 1° `#fffde7→#fff`, 2° `#f5f5f5→#fff`, 3° `#fbe9e7→#fff`
- Medalha emoji no lugar do número (🥇🥈🥉), `fontSize: 20`
- Nome: `Theme.of(context).colorScheme.onSurface`, `fontSize: 15`, `fontWeight: w700`
- Pontos: cor específica por posição — 1° `#b8860b`, 2° `#546e7a`, 3° `#6d4c41`

### Demais posições
- Borda cinza fina `Colors.grey.shade200`, sem gradiente, fundo surface
- Número: `fontSize: 14`, bold, `textSecondary`
- Nome: `Theme.of(context).colorScheme.onSurface`, `fontSize: 14`, `w500`

### Usuário atual (você)
- Fundo `AppColors.success.withOpacity(0.08)`, borda `AppColors.success.withOpacity(0.4)` — comportamento atual mantido

---

## 7. Bug: ListView Recicla Estado do PredictionInput

**Arquivo:** `lib/features/matches/views/matches_screen.dart` (e/ou `_MatchGroupWidget`)

### Causa
`MatchCard` é renderizado sem `key` no `ListView`. Quando um card é removido da lista após submissão de palpite, o Flutter reutiliza o widget state do `PredictionInput` (StatefulWidget) para o próximo card, carregando os valores do controller anterior.

### Fix
Adicionar `key: ValueKey(match.id)` em cada `MatchCard` na lista:
```dart
MatchCard(
  key: ValueKey(match.id),
  match: match,
  competitionCode: competitionCode,
)
```

---

## 8. Bug: Web Reload Causa Erro Permanente

**Arquivo:** `lib/features/matches/viewmodels/matches_viewmodel.dart`

### Causa
Ao recarregar a página web, `MatchesViewModel.build()` dispara imediatamente antes do token JWT ser restaurado do `flutter_secure_storage`. O request retorna 401. O `AuthInterceptor` tenta renovar com o refresh token, mas o `MatchesViewModel` já está em estado de erro. Clicar em "Tentar novamente" falha pela mesma razão — auth ainda não está pronta.

### Fix
Fazer o `build()` do `MatchesViewModel` observar `authViewModelProvider` e só buscar partidas quando o usuário estiver autenticado:

```dart
@override
Future<MatchesState> build(String competitionCode) async {
  final authState = await ref.watch(authViewModelProvider.future);
  if (authState.user == null) return MatchesState(matches: []);
  return _fetchMatches(competitionCode, daysAhead: 7);
}
```

Isso garante que o fetch só acontece após auth estar resolvido. O Riverpod re-executa `build()` automaticamente quando `authViewModelProvider` muda.

---

## Arquivos Afetados

### Frontend
- `lib/features/predictions/views/predictions_screen.dart` — items 1, 2, 3
- `lib/features/predictions/viewmodels/predictions_viewmodel.dart` — item 2 (provider de filtro)
- `lib/features/ranking/views/ranking_screen.dart` — items 5, 6
- `lib/features/ranking/viewmodels/ranking_viewmodel.dart` — item 4
- `lib/features/ranking/data/repositories/ranking_repository.dart` — item 4 (se necessário)
- `lib/features/matches/views/matches_screen.dart` — bug 1
- `lib/features/matches/viewmodels/matches_viewmodel.dart` — bug 2

### Backend
- `src/application/use-cases/` (handler de ranking) — item 4
- `src/api/ranking/` (route handler) — item 4

---

## Fora de Escopo

- Dark mode (feature futura separada)
- Notificações push
- Dashboard pessoal avançado
