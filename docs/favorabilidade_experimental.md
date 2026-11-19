# Motor de favorabilidade ambiental experimental

## Objetivo e limites científicos

O motor resume condições meteorológicas e evidências regionais para apoiar
monitoramento e inspeção visual. Favorabilidade descreve compatibilidade com
critérios configurados; não prevê surgimento de pragas, não fornece diagnóstico,
não é probabilidade estatística de infestação e não recomenda defensivos.
Todos os parâmetros do perfil genérico são experimentais, escolhidos para uma
apresentação acadêmica. Não constituem modelo agronômico validado, nem podem ser
atribuídos a uma espécie real.

## Inspeção da implementação existente

- `FavorabilityEngine`: cálculo síncrono, triagem espacial/temporal,
  deduplicação, média ambiental, evidência regional e classificação.
- `FavorabilityService`: injeção das consultas e conversão para modelos do motor.
- `ScientificRuleRepository`: lê `assets/scientific_rules/pest_rules.json`.
  O esquema é `{ "schemaVersion": 1, "rules": [...] }`; regras individuais
  descrevem organismo, critérios opcionais com unidades fixas, fontes e
  disponibilidade. Uma regra científica utilizável exige fonte identificável.
  O asset atual contém uma lista vazia. Ele foi preservado, sem referências
  fictícias e sem misturar as heurísticas experimentais ao conhecimento científico.
- `WeatherRepository`: Open-Meteo, séries horárias de temperatura, umidade,
  precipitação e vento, cache e fallback explicitamente desatualizado.
  Usa as coordenadas cadastradas na propriedade, sem nova consulta ao GPS.
- `OccurrenceRepository.getSince`: consulta Firestore por `timestamp`.
  `RegionalOccurrence.fromOccurrence` mantém registros com diagnóstico de
  organismo e descarta registros saudáveis ou sem nome. O perfil agrega esses
  registros regionalmente, sem inferir risco de uma espécie específica e sem
  adicionar dependência do serviço de diagnóstico por imagem.
- `PreventiveAlertService`, `PreventiveAlertBuilder` e
  `FirestorePreventiveAlertStore`: política, deduplicação e persistência de
  alertas científicos nas notificações. Continuam independentes do perfil experimental.
- A tela de notificações apresenta os alertas existentes; a nova avaliação
  experimental é acessada no painel da propriedade e exibida localmente.
- `pubspec.yaml`: SDK Dart ^3.11.0, Flutter, Provider, Firebase, http e
  geolocalização já disponíveis; diretório científico já declarado nos assets.
  Não houve alteração de dependências, credenciais ou configurações sensíveis.
- Testes anteriores cobrem motor, regras, alertas preventivos, clima e painel.

## Fórmula preservada

Com os padrões efetivamente encontrados no código:

```
E = média ponderada dos fatores ambientais (pesos padrão iguais)
w_i = 0,5^(idade_em_dias / 7) × 0,5^(distância_em_km / 15)
R = min(1, soma(w_i) / 5)
I = limitar_0_a_100(arredondar(100 × (0,6 E + 0,4 R) / (0,6 + 0,4)))
```

A triagem mantém registros nos últimos 28 dias, inclusive no início da janela,
até 50 km, sem registros futuros, com coordenadas válidas e respeitando cultura
quando conhecida. Duplicatas são eliminadas pelos critérios existentes.
O perfil genérico usa as mesmas funções internas de triagem, evidência regional,
média ambiental e índice usadas pelo motor científico. Seus resultados possuem
tipo separado e não são enviados ao construtor de alertas persistíveis.

Classificação após arredondar: 0–29 baixo, 30–54 moderado, 55–74 alto e 75–100
muito alto. Os pesos e limites são escolhas de engenharia, não inferências científicas.

## Critérios heurísticos

Definidos separadamente em `experimental_profile.dart`, com origem didática
explicitamente experimental:

| Fator | Unidade e período | Pontuação de 0 a 1 |
|---|---|---|
| Temperatura | °C, série horária nas próximas 72 h | Fração das 72 horas entre 22 e 30 °C, inclusive |
| Umidade relativa | %, série horária nas próximas 72 h | Fração das 72 horas com UR ≥ 80% |
| Precipitação | mm acumulados nas próximas 72 h | 1 quando o total está entre 5 e 30 mm, inclusive; 0 fora |
| Evidência regional | Registros recentes, 50 km e 28 dias | Soma ponderada pela fórmula R acima |

O período inicia na hora corrente truncada, seguindo a convenção do motor
existente. O perfil exige as 72 horas consecutivas e os três fatores completos.
Dados ausentes ou inválidos produzem índice indisponível. Não são substituídos
por zero. Temperaturas devem ser finitas e estar entre −90 e 60 °C (limite de
sanidade de software, não limite agronômico); UR deve ser finita entre 0 e 100%;
precipitação deve ser finita e não negativa. Não foi inventado um teto físico
universal de precipitação.

Uma consulta regional vazia tem R = 0 e aviso de que ausência de registros não
significa ausência de risco. Uma consulta regional que falha tem R desconhecido
e não gera índice. Localização inválida também impede o índice. Cache
meteorológico antigo recebe aviso explícito.

## Modos e isolamento

O modo operacional consulta clima e registros reais sob ação do usuário.
Apresenta perfil, índice, nível, fatores, contribuições em pontos, data da
avaliação, obtenção do clima, origem e avisos. O perfil continua experimental
mesmo com dados reais. Ele não publica alertas automaticamente.

O modo demonstração gera uma série horária local e executa o mesmo método
experimental do motor. Temperatura e umidade são constantes; o total de chuva
é colocado na primeira hora simulada, sem simular distribuição meteorológica.
A presença regional equivale a cinco registros independentes, atuais, a zero
quilômetros, de autores distintos: R = 1. A ausência equivale a lista vazia.
Esse artifício controlado é explicitado na interface e não representa uma
distribuição realista de ocorrências.

O banner `MODO DEMONSTRAÇÃO — DADOS SIMULADOS` permanece fora da área rolável.
Entradas e resultado vivem somente no estado da tela. Desativar a demonstração
ou fechar a tela descarta o estado; reativar começa no cenário baixo. Não há
gravação no Firestore, publicação de alertas ou push. O carregador operacional
não é invocado pela demonstração. Respostas operacionais pendentes são
ignoradas se o modo for alterado enquanto a consulta está em voo.

## Roteiro para apresentação

1. Abra uma propriedade e seu **Painel da propriedade**.
2. Selecione **Favorabilidade experimental**.
3. Ative **Modo demonstração**; verifique o banner de dados simulados.
4. Escolha cada nível no seletor e pressione **Executar avaliação**.

| Nível | Temperatura | UR | Chuva em 72 h | Ocorrências simuladas | E | R | Índice |
|---|---:|---:|---:|---|---:|---:|---:|
| Baixo | 15 °C | 50% | 0 mm | Ausentes | 0 | 0 | 0 |
| Moderado | 26 °C | 85% | 0 mm | Ausentes | 2/3 | 0 | 40 |
| Alto | 26 °C | 85% | 12 mm | Ausentes | 1 | 0 | 60 |
| Muito alto | 26 °C | 85% | 12 mm | Presentes (5) | 1 | 1 | 100 |

5. Altere manualmente temperatura, UR ou chuva; a seleção passa a personalizada.
   Execute novamente e explique os fatores pontuados e as duas contribuições.
6. Informe UR de 101% para mostrar dados inválidos sem classificação indevida.
7. Desative a demonstração: o resultado simulado desaparece. Execute uma
   avaliação operacional para carregar dados reais, se disponíveis.

## Validação

Execução em 12/11/2026, com o SDK local `C:\Users\User\flutter`:

- `flutter test --no-pub`: **209 testes aprovados**, incluindo **15 testes
  novos** do perfil experimental e da interface. O uso de `--no-pub` reaproveita
  as dependências resolvidas por `flutter analyze`.
- Cobertura nova: quatro cenários e índices exatos, clima ausente/incompleto,
  valores inválidos/não finitos, ausência e indisponibilidade regional, falha
  meteorológica, cache antigo, limites ambientais e classificatórios, triagem,
  isolamento de entradas reais, preservação do catálogo, descarte ao desativar
  e resposta operacional atrasada durante a demonstração.
- `flutter analyze`: sem problemas nos arquivos da implementação; duas
  observações preexistentes `unnecessary_underscores` na cópia aninhada
  `AgroAdvisor/lib/features/history/presentation/screens/history_screen.dart`,
  linha 395, colunas 47 e 51. O comando termina com código 1 por essas
  observações; não se declara uma análise global limpa.
- `git diff --check`: sem erros de espaço em branco.

A primeira execução revelou problema de rolagem no próprio teste de interface.
O teste passou a localizar a lista rolável explicitamente, e a suíte completa
foi executada novamente. Não houve teste manual em aparelho nem consulta aos
serviços de produção durante esta validação.

## Limitações e pendências

- Nenhuma validação de campo, calibração estatística, sensibilidade ou
  especificidade foi realizada. O perfil não distingue cultura ou espécie.
- Agregação regional de organismos distintos é apenas contexto genérico;
  não constitui evidência epidemiológica para uma praga específica.
- Não há modelo de ausência de reporte, cobertura de usuários, viés de
  notificação, qualidade dos diagnósticos ou representatividade espacial.
- O relógio do aparelho deve acompanhar a hora local da propriedade: o código
  meteorológico existente representa horários Open-Meteo como hora de parede.
  Análises entre fusos distintos precisam de tratamento adicional.
- O catálogo científico permanece vazio: alertas específicos de organismos
  continuam sem índice enquanto não houver regras com fontes reais adequadas.
- A demonstração exige acesso ao painel de uma propriedade cadastrada.
- Os testes automatizados não substituem execução manual em aparelho nem
  uma verificação de integração com Firestore/Open-Meteo autenticados.
