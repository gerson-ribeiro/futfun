# Predictions & Ranking Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir 2 bugs críticos e entregar 6 melhorias de UX nas telas de Palpites e Ranking.

**Architecture:** Todas as mudanças são no frontend Flutter (MVVM + Riverpod), exceto a Task 6 que altera o endpoint de ranking no backend Next.js para retornar todos os usuários (não só os que pontuaram). Nenhuma migração de banco necessária — o schema já suporta.

**Tech Stack:** Flutter/Riverpod (frontend), Next.js/Prisma/PostgreSQL (backend), Deploy via Cloud Run + Firebase Hosting.

---

## Mapa de Arquivos

| Arquivo | Tasks |
|---------|-------|
| `futfun-frontend/lib/features/matches/views/matches_screen.dart` | Task 1 |
| `futfun-frontend/lib/features/matches/viewmodels/matches_viewmodel.dart` | Task 2 |
| `futfun-frontend/lib/features/predictions/views/predictions_screen.dart` | Tasks 3, 4, 5 |
| `futfun-backend/app/api/rankings/route.ts` | Task 6 |
| `futfun-backend/app/api/rankings/me/route.ts` | Task 6 |
| `futfun-frontend/lib/features/ranking/views/ranking_screen.dart` | Task 7 |

---

## Task 1: Bug — ListView recicla estado do PredictionInput

**Arquivos:**
- Modify: `futfun-frontend/lib/features/matches/views/matches_screen.dart`

**Contexto:** `MatchCard` é um `StatefulWidget` sem `key`. Quando um card é removido da lista (após palpitar), o Flutter reutiliza o estado do `PredictionInput` do card removido para o próximo card, carregando os valores antigos. Fix: `ValueKey(match.id)`.

- [ ] **Step 1: Localizar o ponto de renderização dos cards**

Abrir `futfun-frontend/lib/features/matches/views/matches_screen.dart`, localizar a classe `_MatchGroupWidget` (~linha 209). O trecho atual é:

```dart
...group.matchIds.map((id) {
  final match = matchesState.matches.firstWhere((m) => m.id == id);
  return MatchCard(
    match: match,
    competitionCode: competitionCode,
  );
}),
```

- [ ] **Step 2: Adicionar ValueKey em cada MatchCard**

Substituir o trecho acima por:

```dart
...group.matchIds.map((id) {
  final match = matchesState.matches.firstWhere((m) => m.id == id);
  return MatchCard(
    key: ValueKey(match.id),
    match: match,
    competitionCode: competitionCode,
  );
}),
```

- [ ] **Step 3: Verificar que MatchCard aceita key**

`MatchCard` extends `ConsumerWidget`, que herda de `Widget`. O parâmetro `key` já existe no construtor base — nenhuma mudança no `MatchCard` é necessária.

- [ ] **Step 4: Build para verificar ausência de erros**

```bash
cd futfun-frontend
flutter build web --no-tree-shake-icons 2>&1 | tail -5
```

Esperado: `✓ Built build/web` sem erros.

- [ ] **Step 5: Commit**

```bash
cd futfun-frontend
git add lib/features/matches/views/matches_screen.dart
git commit -m "fix: ValueKey em MatchCard previne reuso de estado do PredictionInput"
```

---

## Task 2: Bug — Web reload causa erro permanente na tela de jogos

**Arquivos:**
- Modify: `futfun-frontend/lib/features/matches/viewmodels/matches_viewmodel.dart`

**Contexto:** No web, ao recarregar a página, `MatchesViewModel.build()` dispara antes do `AuthViewModel` restaurar o token do storage. Isso causa 401 no primeiro request. O botão "Tentar novamente" falha pela mesma razão. Fix: assistir `authViewModelProvider` e só buscar partidas quando o usuário estiver autenticado.

- [ ] **Step 1: Adicionar import de auth no viewmodel**

Abrir `futfun-frontend/lib/features/matches/viewmodels/matches_viewmodel.dart`. No topo do arquivo, após os imports existentes, adicionar:

```dart
import '../../auth/viewmodels/auth_viewmodel.dart';
```

- [ ] **Step 2: Aguardar auth antes de buscar partidas**

Localizar o método `build` (~linha 46):

```dart
@override
// ignore: avoid_renaming_method_parameters
Future<MatchesState> build(String competitionCode) async {
  return _fetchMatches(competitionCode, daysAhead: 7);
}
```

Substituir por:

```dart
@override
// ignore: avoid_renaming_method_parameters
Future<MatchesState> build(String competitionCode) async {
  final authState = await ref.watch(authViewModelProvider.future);
  if (authState.stage == AuthStage.unauthenticated) {
    return const MatchesState(matches: []);
  }
  return _fetchMatches(competitionCode, daysAhead: 7);
}
```

Isso faz o Riverpod re-executar `build()` automaticamente sempre que o estado de auth mudar (ex: login completo após reload). Se o token existir no storage, `authViewModelProvider` resolve imediatamente com o stage correto.

- [ ] **Step 3: Build para verificar ausência de erros**

```bash
cd futfun-frontend
flutter build web --no-tree-shake-icons 2>&1 | tail -5
```

Esperado: `✓ Built build/web` sem erros.

- [ ] **Step 4: Commit**

```bash
cd futfun-frontend
git add lib/features/matches/viewmodels/matches_viewmodel.dart
git commit -m "fix: MatchesViewModel aguarda auth antes de buscar partidas (web reload)"
```

---

## Task 3: Palpite em destaque no card de predições

**Arquivos:**
- Modify: `futfun-frontend/lib/features/predictions/views/predictions_screen.dart`

**Contexto:** A linha do palpite atual é texto cinza pequeno. O novo design mostra um badge laranja com o placar e mantém o badge de pontos à direita.

- [ ] **Step 1: Localizar a prediction row no _PredictionCard**

Abrir `futfun-frontend/lib/features/predictions/views/predictions_screen.dart`. Localizar o trecho na `build` de `_PredictionCard` (~linha 347):

```dart
// Prediction row
Row(
  children: [
    const Icon(Icons.sports_soccer, size: 14, color: AppColors.textSecondary),
    const SizedBox(width: 6),
    Text(
      'Palpite: ${prediction.predictedHome} × ${prediction.predictedAway}',
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
    ),
    const Spacer(),
    if (isEditable)
      // ... botão editar
```

- [ ] **Step 2: Substituir a prediction row pelo novo design**

Substituir toda a `Row` de prediction (do `Row(` até o `),` que fecha o `Row` — inclusive o `const SizedBox(height: 8), const Divider(height: 1), const SizedBox(height: 8),` que vem antes) pelo seguinte:

```dart
const SizedBox(height: 8),
const Divider(height: 1),
const SizedBox(height: 8),
// Prediction row
Row(
  children: [
    const Icon(Icons.sports_soccer, size: 14, color: AppColors.textSecondary),
    const SizedBox(width: 6),
    const Text(
      'Meu palpite:',
      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
    ),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        border: Border.all(color: const Color(0xFFF57C00)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${prediction.predictedHome} × ${prediction.predictedAway}',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFFE65100),
        ),
      ),
    ),
    const Spacer(),
    if (isEditable)
      TextButton.icon(
        onPressed: () => _showEditDialog(context, ref, prediction),
        icon: const Icon(Icons.edit, size: 14),
        label: const Text('Editar', style: TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      )
    else if (pts != null)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: ptsColor?.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ptsColor ?? AppColors.textSecondary),
        ),
        child: Text(
          pts > 0 ? '+$pts pts' : '0 pts',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: ptsColor,
          ),
        ),
      )
    else if (isFinished)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Text(
          'Apurando...',
          style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
        ),
      )
    else
      const Text(
        'Aguardando',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
  ],
),
```

- [ ] **Step 3: Build e verificar**

```bash
cd futfun-frontend
flutter build web --no-tree-shake-icons 2>&1 | tail -5
```

Esperado: `✓ Built build/web` sem erros.

- [ ] **Step 4: Commit**

```bash
cd futfun-frontend
git add lib/features/predictions/views/predictions_screen.dart
git commit -m "feat: palpite em destaque com badge laranja no card de predições"
```

---

## Task 4: Filtros e ordenação inteligente na tela de palpites

**Arquivos:**
- Modify: `futfun-frontend/lib/features/predictions/views/predictions_screen.dart`

**Contexto:** Adicionar chips de filtro (Todos/Agendados/Encerrados) + botão de ordenação na AppBar. O padrão é: agendados no topo, encerrados abaixo (mais recentes primeiro). Estado de filtro e ordem são `StateProvider` locais na tela.

- [ ] **Step 1: Adicionar providers de estado de filtro e ordem**

No topo de `predictions_screen.dart`, após os imports, adicionar:

```dart
// 'all' | 'scheduled' | 'finished'
final _predFilterProvider = StateProvider<String>((ref) => 'all');
// true = encerrados mais recentes primeiro (padrão), false = mais antigos primeiro
final _predSortDescProvider = StateProvider<bool>((ref) => true);
```

- [ ] **Step 2: Atualizar a AppBar para incluir botão de ordenação**

Localizar o `AppBar` dentro do `Scaffold` de `PredictionsScreen.build`. Substituir:

```dart
appBar: AppBar(
  title: const Text('Meus Palpites'),
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
  leading: buildLeadingWidget(context, ref),
  actions: [
    IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: () => ref.read(predictionsViewModelProvider.notifier).refresh(),
    ),
    ...buildAppBarActions(context, ref),
  ],
),
```

Por:

```dart
appBar: AppBar(
  title: const Text('Meus Palpites'),
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
  leading: buildLeadingWidget(context, ref),
  actions: [
    IconButton(
      icon: Icon(ref.watch(_predSortDescProvider)
          ? Icons.arrow_downward
          : Icons.arrow_upward),
      tooltip: ref.watch(_predSortDescProvider)
          ? 'Mais antigos primeiro'
          : 'Mais recentes primeiro',
      onPressed: () => ref
          .read(_predSortDescProvider.notifier)
          .state = !ref.read(_predSortDescProvider),
    ),
    IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: () => ref.read(predictionsViewModelProvider.notifier).refresh(),
    ),
    ...buildAppBarActions(context, ref),
  ],
),
```

- [ ] **Step 3: Adicionar os chips de filtro entre AppBar e lista**

Localizar o `body:` do Scaffold. Atualmente o body vai direto para o `asyncState.when(...)`. Substituir a parte do `data:` onde a lista é renderizada para envolver em uma `Column` com os chips acima.

Localizar no `data: (predictions)` o trecho que retorna `RefreshIndicator`. Substituir por:

```dart
data: (predictions) {
  if (predictions.isEmpty) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_soccer, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'Nenhum palpite realizado ainda',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          SizedBox(height: 8),
          Text(
            'Vá para Jogos e faça seus palpites!',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  final filter = ref.watch(_predFilterProvider);
  final sortDesc = ref.watch(_predSortDescProvider);
  final filtered = _applyFilter(predictions, filter);
  final groups = _groupSmart(filtered, sortDesc: sortDesc);

  return Column(
    children: [
      // Filter chips
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            _FilterChip(label: 'Todos', value: 'all', provider: _predFilterProvider),
            const SizedBox(width: 8),
            _FilterChip(label: 'Agendados', value: 'scheduled', provider: _predFilterProvider),
            const SizedBox(width: 8),
            _FilterChip(label: 'Encerrados', value: 'finished', provider: _predFilterProvider),
          ],
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => ref.read(predictionsViewModelProvider.notifier).refresh(),
          child: groups.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum palpite neste filtro',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            group.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...group.predictions.map(
                          (p) => _PredictionCard(prediction: p),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    ],
  );
},
```

- [ ] **Step 4: Adicionar os métodos de filtro e agrupamento inteligente**

Dentro de `PredictionsScreen` (ou como funções top-level no arquivo), substituir o método `_groupByStage` e adicionar os novos:

```dart
List<PredictionWithMatch> _applyFilter(
    List<PredictionWithMatch> predictions, String filter) {
  switch (filter) {
    case 'scheduled':
      return predictions
          .where((p) => p.match.status != 'FINISHED')
          .toList();
    case 'finished':
      return predictions
          .where((p) => p.match.status == 'FINISHED')
          .toList();
    default:
      return predictions;
  }
}

List<_PredictionGroup> _groupSmart(
    List<PredictionWithMatch> predictions, {bool sortDesc = true}) {
  final upcoming = predictions
      .where((p) => p.match.status != 'FINISHED')
      .toList()
    ..sort((a, b) => a.match.kickoffTime.compareTo(b.match.kickoffTime));

  final finished = predictions
      .where((p) => p.match.status == 'FINISHED')
      .toList()
    ..sort((a, b) => sortDesc
        ? b.match.kickoffTime.compareTo(a.match.kickoffTime)
        : a.match.kickoffTime.compareTo(b.match.kickoffTime));

  final groups = <_PredictionGroup>[];
  if (upcoming.isNotEmpty) {
    groups.add(_PredictionGroup(label: '📅 Próximos', predictions: upcoming));
  }
  if (finished.isNotEmpty) {
    groups.add(_PredictionGroup(label: '✅ Encerrados', predictions: finished));
  }
  return groups;
}
```

Remover o método `_groupByStage` antigo (não é mais usado).

- [ ] **Step 5: Adicionar o widget _FilterChip**

No final do arquivo, adicionar o widget auxiliar:

```dart
class _FilterChip extends ConsumerWidget {
  final String label;
  final String value;
  final StateProvider<String> provider;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(provider);
    final isActive = current == value;
    return GestureDetector(
      onTap: () => ref.read(provider.notifier).state = value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Build e verificar**

```bash
cd futfun-frontend
flutter build web --no-tree-shake-icons 2>&1 | tail -5
```

Esperado: `✓ Built build/web` sem erros.

- [ ] **Step 7: Commit**

```bash
cd futfun-frontend
git add lib/features/predictions/views/predictions_screen.dart
git commit -m "feat: filtros e agrupamento inteligente na tela de palpites"
```

---

## Task 5: Explicação de pontos inline no card de predições

**Arquivos:**
- Modify: `futfun-frontend/lib/features/predictions/views/predictions_screen.dart`

**Contexto:** Ao tocar num card encerrado com pontos calculados, o card expande mostrando o breakdown dos pontos (checklist inline). Implementado com `ConsumerStatefulWidget` para ter estado local `_expanded`.

**Regras de pontuação:**
- Resultado certo (mesmo winner/draw): +5
- Resultado certo + 1 placar correto: +7 total (+2 bonus)
- Placar exato (ambos corretos): +10 total
- Resultado errado: 0

- [ ] **Step 1: Converter _PredictionCard para ConsumerStatefulWidget**

Localizar a classe `_PredictionCard` (~linha 259). Substituir toda a classe pela versão stateful:

```dart
class _PredictionCard extends ConsumerStatefulWidget {
  final PredictionWithMatch prediction;
  const _PredictionCard({required this.prediction});

  @override
  ConsumerState<_PredictionCard> createState() => _PredictionCardState();
}

class _PredictionCardState extends ConsumerState<_PredictionCard> {
  bool _expanded = false;

  PredictionWithMatch get prediction => widget.prediction;

  // Calcula o breakdown de pontos localmente
  List<_BreakdownItem> _buildBreakdown() {
    final m = prediction.match;
    final ph = prediction.predictedHome;
    final pa = prediction.predictedAway;
    final sh = m.scoreHome ?? 0;
    final sa = m.scoreAway ?? 0;

    int sign(int v) => v > 0 ? 1 : (v < 0 ? -1 : 0);
    final resultCorrect = sign(ph - pa) == sign(sh - sa);
    final homeCorrect = ph == sh;
    final awayCorrect = pa == sa;

    if (!resultCorrect) {
      return [
        _BreakdownItem(ok: false, label: 'Resultado errado', pts: 0),
      ];
    }

    if (homeCorrect && awayCorrect) {
      return [
        _BreakdownItem(ok: true, label: 'Placar exato! ($ph × $pa)', pts: 10),
      ];
    }

    return [
      _BreakdownItem(ok: true, label: 'Resultado certo', pts: 5),
      if (homeCorrect)
        _BreakdownItem(ok: true, label: 'Placar do mandante correto ($ph)', pts: 2)
      else if (awayCorrect)
        _BreakdownItem(ok: true, label: 'Placar do visitante correto ($pa)', pts: 2),
      if (!homeCorrect)
        _BreakdownItem(
            ok: false,
            label: 'Placar do mandante errado ($ph ≠ $sh)',
            pts: 0),
      if (!awayCorrect)
        _BreakdownItem(
            ok: false,
            label: 'Placar do visitante errado ($pa ≠ $sa)',
            pts: 0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final m = prediction.match;
    final pts = prediction.points;
    final now = DateTime.now();
    final isFinished = m.status == 'FINISHED';
    final isEditable = m.status == 'SCHEDULED' &&
        m.kickoffTime.isAfter(now) &&
        m.kickoffTime.difference(now).inDays <= 1;

    // Clicável apenas quando encerrado e com pontos calculados
    final isExpandable = isFinished && pts != null;

    Color? ptsColor;
    if (pts != null) {
      if (pts >= 10) ptsColor = AppColors.success;
      else if (pts >= 5) ptsColor = Colors.orange;
      else ptsColor = AppColors.textSecondary;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isExpandable
            ? () => setState(() => _expanded = !_expanded)
            : (isEditable ? () => _showEditDialog(context, ref, prediction) : null),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date + status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd/MM HH:mm').format(m.kickoffTime.toLocal()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      _buildStatusBadge(m.status),
                      if (isExpandable) ...[
                        const SizedBox(width: 4),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Teams row
              Row(
                children: [
                  Expanded(
                    child: _TeamDisplay(
                      name: m.homeTeamShort ?? m.homeTeamName,
                      crestUrl: m.homeTeamCrest,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: isFinished
                        ? Text(
                            '${m.scoreHome ?? 0} - ${m.scoreAway ?? 0}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Text(
                            'vs',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                  ),
                  Expanded(
                    child: _TeamDisplay(
                      name: m.awayTeamShort ?? m.awayTeamName,
                      crestUrl: m.awayTeamCrest,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              // Prediction row (destaque)
              Row(
                children: [
                  const Icon(Icons.sports_soccer, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  const Text(
                    'Meu palpite:',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      border: Border.all(color: const Color(0xFFF57C00)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${prediction.predictedHome} × ${prediction.predictedAway}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isEditable)
                    TextButton.icon(
                      onPressed: () => _showEditDialog(context, ref, prediction),
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Editar', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else if (pts != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ptsColor?.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ptsColor ?? AppColors.textSecondary),
                      ),
                      child: Text(
                        pts > 0 ? '+$pts pts' : '0 pts',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ptsColor,
                        ),
                      ),
                    )
                  else if (isFinished)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        'Apurando...',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                      ),
                    )
                  else
                    const Text(
                      'Aguardando',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
              // Breakdown inline (expandido)
              if (_expanded && isExpandable) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COMO GANHEI ESTES PONTOS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ..._buildBreakdown().map((item) => _BreakdownRow(item: item)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'LIVE':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        label = 'AO VIVO';
      case 'FINISHED':
        bg = Colors.grey.shade200;
        fg = AppColors.textSecondary;
        label = 'Encerrado';
      default:
        bg = Colors.blue.shade50;
        fg = AppColors.primary;
        label = 'Agendado';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}
```

- [ ] **Step 2: Adicionar os tipos auxiliares _BreakdownItem e _BreakdownRow**

No final do arquivo, adicionar:

```dart
class _BreakdownItem {
  final bool ok;
  final String label;
  final int pts;
  const _BreakdownItem({required this.ok, required this.label, required this.pts});
}

class _BreakdownRow extends StatelessWidget {
  final _BreakdownItem item;
  const _BreakdownRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            item.ok ? '✅' : '❌',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                color: item.ok ? const Color(0xFF424242) : AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            item.pts > 0 ? '+${item.pts}' : '+0',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: item.ok && item.pts > 0 ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Nota:** Neste ponto, a Task 4 já substituiu `_PredictionCard` por `ConsumerStatefulWidget`. Se executando as tasks em ordem, a Task 4 mudou o widget para stateful mas sem o breakdown. Esta task sobrescreve a classe completa com ambas as features (badges + breakdown). Certifique-se de que a Task 4 foi commitada antes.

- [ ] **Step 3: Build e verificar**

```bash
cd futfun-frontend
flutter build web --no-tree-shake-icons 2>&1 | tail -5
```

Esperado: `✓ Built build/web` sem erros.

- [ ] **Step 4: Commit**

```bash
cd futfun-frontend
git add lib/features/predictions/views/predictions_screen.dart
git commit -m "feat: explicação inline de pontos ao clicar em palpite encerrado"
```

---

## Task 6: Backend — Ranking retorna todos os usuários

**Arquivos:**
- Modify: `futfun-backend/app/api/rankings/route.ts`
- Modify: `futfun-backend/app/api/rankings/me/route.ts`

**Contexto:** Hoje o endpoint GET `/api/rankings` filtra `totalPoints > 0`, ocultando usuários sem pontuação. Precisa retornar todos os MEMBERs e ADMINs, mesmo com 0 pontos e 0 palpites.

**Estratégia:** Fazer LEFT JOIN de `User` com `UserCompetitionStats`. Como Prisma não tem LEFT JOIN nativo simples, buscar todos os usuários elegíveis e suas stats (se existirem), depois combinar e ordenar em memória.

- [ ] **Step 1: Atualizar GET /api/rankings**

Abrir `futfun-backend/app/api/rankings/route.ts`. Substituir o conteúdo completo por:

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const GET = withAuth(async (req: NextRequest, _user: TokenPayload) => {
  try {
    const competitionCode = req.nextUrl.searchParams.get('competitionCode');
    if (!competitionCode) {
      return NextResponse.json({ error: 'competitionCode is required' }, { status: 400 });
    }

    const { prisma } = getContainer();

    // Busca todos os usuários elegíveis (MEMBER e ADMIN) com suas stats para esta liga
    const users = await prisma.user.findMany({
      where: { role: { in: ['MEMBER', 'ADMIN'] } },
      select: {
        id: true,
        displayName: true,
        competitionStats: {
          where: { competitionCode },
        },
      },
    });

    // Constrói entradas com 0s para quem não tem stats
    const entries = users.map((user) => {
      const stats = user.competitionStats[0];
      return {
        userId: user.id,
        displayName: user.displayName,
        totalPoints: stats?.totalPoints ?? 0,
        exactScores: stats?.exactScores ?? 0,
        correctResults: stats?.correctResults ?? 0,
        matchesPredicted: stats?.matchesPredicted ?? 0,
      };
    });

    // Ordena pelas regras de desempate
    entries.sort((a, b) => {
      if (b.totalPoints !== a.totalPoints) return b.totalPoints - a.totalPoints;
      if (b.exactScores !== a.exactScores) return b.exactScores - a.exactScores;
      if (b.correctResults !== a.correctResults) return b.correctResults - a.correctResults;
      return a.matchesPredicted - b.matchesPredicted;
    });

    const rankings = entries.map((entry, index) => ({
      position: index + 1,
      ...entry,
    }));

    return NextResponse.json({ rankings });
  } catch (error) {
    return handleError(error);
  }
});
```

- [ ] **Step 2: Atualizar GET /api/rankings/me**

Abrir `futfun-backend/app/api/rankings/me/route.ts`. Substituir o conteúdo completo por:

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const GET = withAuth(async (req: NextRequest, user: TokenPayload) => {
  try {
    const competitionCode = req.nextUrl.searchParams.get('competitionCode');
    if (!competitionCode) {
      return NextResponse.json({ error: 'competitionCode is required' }, { status: 400 });
    }

    const { prisma } = getContainer();

    // Mesma lógica do /rankings para determinar a posição real do usuário
    const users = await prisma.user.findMany({
      where: { role: { in: ['MEMBER', 'ADMIN'] } },
      select: {
        id: true,
        displayName: true,
        competitionStats: {
          where: { competitionCode },
        },
      },
    });

    const entries = users.map((u) => {
      const stats = u.competitionStats[0];
      return {
        userId: u.id,
        displayName: u.displayName,
        totalPoints: stats?.totalPoints ?? 0,
        exactScores: stats?.exactScores ?? 0,
        correctResults: stats?.correctResults ?? 0,
        matchesPredicted: stats?.matchesPredicted ?? 0,
      };
    });

    entries.sort((a, b) => {
      if (b.totalPoints !== a.totalPoints) return b.totalPoints - a.totalPoints;
      if (b.exactScores !== a.exactScores) return b.exactScores - a.exactScores;
      if (b.correctResults !== a.correctResults) return b.correctResults - a.correctResults;
      return a.matchesPredicted - b.matchesPredicted;
    });

    const positionIndex = entries.findIndex((e) => e.userId === user.userId);

    if (positionIndex === -1) {
      return NextResponse.json({ ranking: null });
    }

    const entry = entries[positionIndex];
    return NextResponse.json({
      ranking: {
        position: positionIndex + 1,
        ...entry,
      },
    });
  } catch (error) {
    return handleError(error);
  }
});
```

- [ ] **Step 3: Verificar build do backend**

```bash
cd futfun-backend
npm run build 2>&1 | tail -10
```

Esperado: sem erros TypeScript.

- [ ] **Step 4: Commit**

```bash
cd futfun-backend
git add app/api/rankings/route.ts app/api/rankings/me/route.ts
git commit -m "feat: ranking retorna todos os usuários elegíveis (não só quem pontuou)"
```

---

## Task 7: Ranking — cards redesenhados + contagem de palpites

**Arquivos:**
- Modify: `futfun-frontend/lib/features/ranking/views/ranking_screen.dart`

**Contexto:** Os cards do ranking ganham destaque visual para top 3 (borda lateral colorida + gradiente sutil) e exibem a contagem de palpites abaixo do nome. Nomes usam `Theme.of(context).colorScheme.onSurface` para funcionar em ambos os temas.

**Cores das bordas:** 1° `#FFD700` (ouro), 2° `#B0BEC5` (prata), 3° `#BF8C60` (bronze).
**Gradientes:** 1° `#fffde7→#fff`, 2° `#f5f5f5→#fff`, 3° `#fbe9e7→#fff`.

- [ ] **Step 1: Reescrever _RankingRow com o novo design**

Localizar a classe `_RankingRow` (~linha 155) em `futfun-frontend/lib/features/ranking/views/ranking_screen.dart`. Substituir a classe inteira por:

```dart
class _RankingRow extends StatelessWidget {
  final RankingEntry entry;
  final bool isCurrentUser;
  final bool compact;

  const _RankingRow({
    required this.entry,
    this.isCurrentUser = false,
    this.compact = false,
  });

  // Medalhas apenas para top 3
  static String _medal(int pos) {
    if (pos == 1) return '🥇';
    if (pos == 2) return '🥈';
    if (pos == 3) return '🥉';
    return '';
  }

  // Borda esquerda colorida para top 3
  static Color _borderColor(int pos) {
    if (pos == 1) return const Color(0xFFFFD700);
    if (pos == 2) return const Color(0xFFB0BEC5);
    if (pos == 3) return const Color(0xFFBF8C60);
    return Colors.grey.shade200;
  }

  // Gradiente de fundo para top 3
  static List<Color> _gradientColors(int pos) {
    if (pos == 1) return [const Color(0xFFFFFDE7), Colors.white];
    if (pos == 2) return [const Color(0xFFF5F5F5), Colors.white];
    if (pos == 3) return [const Color(0xFFFBE9E7), Colors.white];
    return [Colors.transparent, Colors.transparent];
  }

  // Cor dos pontos para top 3
  static Color _ptsColor(int pos, BuildContext context) {
    if (pos == 1) return const Color(0xFFB8860B);
    if (pos == 2) return const Color(0xFF546E7A);
    if (pos == 3) return const Color(0xFF6D4C41);
    return Theme.of(context).colorScheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    final medal = _medal(entry.position);
    final isTop3 = entry.position <= 3;
    final borderColor = isCurrentUser
        ? AppColors.success.withOpacity(0.4)
        : _borderColor(entry.position);
    final gradColors = isCurrentUser
        ? [AppColors.success.withOpacity(0.08), AppColors.success.withOpacity(0.04)]
        : _gradientColors(entry.position);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        gradient: isTop3 || isCurrentUser
            ? LinearGradient(
                colors: gradColors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: (!isTop3 && !isCurrentUser)
            ? Theme.of(context).colorScheme.surface
            : null,
        borderRadius: BorderRadius.circular(10),
        border: isCurrentUser
            ? Border.all(color: borderColor, width: 1.5)
            : (isTop3
                ? Border(
                    left: BorderSide(color: borderColor, width: 5),
                    top: BorderSide(color: Colors.grey.shade100),
                    right: BorderSide(color: Colors.grey.shade100),
                    bottom: BorderSide(color: Colors.grey.shade100),
                  )
                : Border.all(color: Colors.grey.shade200)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Posição / Medalha
            SizedBox(
              width: 36,
              child: medal.isNotEmpty
                  ? Text(medal, style: const TextStyle(fontSize: 20))
                  : Text(
                      '${entry.position}°',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isCurrentUser
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
            ),
            // Nome + contagem de palpites
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName + (isCurrentUser ? ' (você)' : ''),
                    style: TextStyle(
                      fontSize: isTop3 ? 15 : 14,
                      fontWeight: isTop3 ? FontWeight.w700 : (isCurrentUser ? FontWeight.w700 : FontWeight.w500),
                      color: isCurrentUser
                          ? AppColors.success
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!compact)
                    Text(
                      '${entry.matchesPredicted} palpites',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            // Acertos (só quando não compacto)
            if (!compact) ...[
              Text(
                '${entry.exactScores}✓✓ ${entry.correctResults}✓',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
            ],
            // Pontos
            Text(
              '${entry.totalPoints} pts',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isCurrentUser
                    ? AppColors.success
                    : _ptsColor(entry.position, context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Build e verificar**

```bash
cd futfun-frontend
flutter build web --no-tree-shake-icons 2>&1 | tail -5
```

Esperado: `✓ Built build/web` sem erros.

- [ ] **Step 3: Commit**

```bash
cd futfun-frontend
git add lib/features/ranking/views/ranking_screen.dart
git commit -m "feat: ranking com destaque top 3, fontes maiores e contagem de palpites"
```

---

## Task 8: Deploy

- [ ] **Step 1: Deploy do backend**

```powershell
$env:CLOUDSDK_PYTHON="C:\Users\gugag\AppData\Local\Google\Cloud SDK\google-cloud-sdk\platform\bundledpython\python.exe"
cd E:\source\personal\futfun\futfun-backend
gcloud builds submit --project futfun-498118
```

Aguardar conclusão. Verificar no console do Cloud Run que a nova revisão está ativa.

- [ ] **Step 2: Deploy do frontend**

```powershell
cd E:\source\personal\futfun\futfun-frontend
flutter build web --no-tree-shake-icons
firebase deploy --only hosting
```

Aguardar mensagem `✔ Deploy complete!` e abrir https://futfun-385ea.web.app para verificar.

- [ ] **Step 3: Verificação pós-deploy**

Checar manualmente:
1. Tela de Jogos: fazer dois palpites sem clicar em "Palpitar" → verificar que o segundo não perde o valor após submeter o primeiro (bug 1 corrigido)
2. Recarregar o browser na tela de Jogos → verificar que carrega sem erro (bug 2 corrigido)
3. Tela de Palpites: verificar badge laranja nos palpites
4. Tela de Palpites: verificar chips de filtro e grupos "Próximos" / "Encerrados"
5. Tela de Palpites: tocar em palpite encerrado com pontos → verificar breakdown inline
6. Tela de Ranking: verificar que todos os 4 jogadores aparecem
7. Tela de Ranking: verificar borda dourada no 1°, prata no 2°, bronze no 3°

---

## Self-Review — Cobertura do Spec

| Item do Spec | Task |
|---|---|
| 1. Palpite em destaque (badge laranja) | Task 3 ✓ |
| 2. Filtros Todos/Agendados/Encerrados + ordenação | Task 4 ✓ |
| 3. Explicação de pontos inline | Task 5 ✓ |
| 4. Ranking mostra todos os usuários | Task 6 ✓ |
| 5. Contagem de palpites no ranking | Task 7 ✓ |
| 6. Cards redesenhados com destaque top 3 | Task 7 ✓ |
| 7. Bug ListView key | Task 1 ✓ |
| 8. Bug web reload auth | Task 2 ✓ |

**Nota sobre Task 3 e Task 5:** A Task 3 implementa apenas o badge de palpite. A Task 5 reescreve `_PredictionCard` por inteiro com badge + breakdown. Ao executar em ordem, a Task 3 é essencialmente absorvida pela Task 5. Se executando com subagents, o subagent da Task 5 deve ter ciência que está sobrescrevendo o que a Task 3 fez (e o código da Task 5 já inclui o badge, então não há perda).
