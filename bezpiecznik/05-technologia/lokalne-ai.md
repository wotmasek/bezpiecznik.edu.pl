# Lokalne AI

## Rola

Lokalny model językowy rozumie pytanie użytkownika i układa odpowiedź z fragmentów oficjalnych źródeł. Nie jest źródłem wiedzy. Zasady: [odpowiedzi tylko ze źródeł](../02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md).

## Model

**Wybrany model: Gemma 4 E2B** (Google DeepMind, kwiecień 2026, licencja Apache 2.0).

| Cecha | Wartość |
|---|---|
| Rozmiar | ≈ 2,3 mld efektywnych parametrów, 2,58 GB wg strony LiteRT-LM Google (sprawdzone 2026-11-21). Pomiary Google: pierwszy token 0,3 s na GPU / 1,8 s na CPU (S26 Ultra); telefon demo zmierzyć w godzinie 2 |
| Pamięć telefonu | Minimum 6 GB RAM; aplikacja z modelem zajmuje ≈ 2,5 GB ([wymagania systemowe](wymagania-systemowe.md)) |
| Uruchomienie | `flutter_edge_ai` (następca wycofanego `flutter_gemma`; migracja: zmiana importu i `dart fix --apply`), plik `.litertlm`, Android i iOS, bez sieci. Nazwy API sprawdzić w aktualnej dokumentacji pakietu |
| Format odpowiedzi | Wymuszony format ze schematem JSON (`responseFormat: ResponseFormat.jsonSchema(...)` w `openChat`, od 2.6.0), bez wywoływania narzędzi: według dokumentacji pakietu formatu nie łączy się z narzędziami ani z `enableThinking: true`. Szczegóły: [format odpowiedzi](#format-odpowiedzi) |
| Tryb myślenia | Wyłączony, bo wydłuża czas odpowiedzi |
| Wejście audio | Obsługiwane (klip do 30 s, mono 16 kHz). Wybrany model do transkrypcji głosówek w P2: [rozmowa głosowa](../02-funkcje/08-w-przyszlosci/glos.md) |

**Dlaczego:** mieści się na większości telefonów, dobrze słucha poleceń, a `flutter_edge_ai` potrafi wymusić ustalony format odpowiedzi, którego wymaga [sprawdzanie odpowiedzi](../02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md).

**Wymagania do sprawdzenia na docelowym telefonie:**
- Jakość na [zestawie testowym](../02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md#zestaw-testowy): wszystkie oczekiwane odmowy i poprawne cytaty po polsku.
- Szybkość: czas ładowania, czas do pierwszego słowa (cel: około 8 sekund), tokeny na sekundę.

**Alternatywy, gdy E2B nie spełni wymagań:**
- **Gemma 4 E4B** (3,65 GB wg LiteRT-LM, 8 GB+ RAM): lepsza jakość na mocniejszych telefonach, ta sama integracja.
- **Bielik 4.5B v3** (SpeakLeash, `Bielik-4.5B-v3.0-Instruct-GGUF`): polski model z polskim tokenizerem, uruchamiany przez llama.cpp (`llama_cpp_dart` lub `fllama`). Format odpowiedzi trzeba wymuszać promptem lub gramatyką llama.cpp.

## Embeddingi

**Po MVP** (w MVP samo FTS5). Mały, wielojęzyczny model wektorowy: EmbeddingGemma przez `flutter_edge_ai` (API embeddingów zmieniło się w 2.3.0) albo model ONNX (np. multilingual-e5-small). Ten sam model przy budowie bazy na komputerze i w aplikacji. Fragmentów jest najwyżej kilka tysięcy, więc podobieństwo liczy się w Dart, bez osobnej bazy wektorowej.

## Wyszukiwanie

1. Wyszukiwanie pełnotekstowe (FTS5); po MVP równolegle wektorowe.
2. Połączenie wyników i wybór kilku najlepszych fragmentów.
3. Próg pewności: poniżej progu model nie jest uruchamiany.

## Format odpowiedzi

Model zwraca jeden obiekt JSON zgodny ze schematem paneli. Model pisze tekst kroków, walidator go sprawdza ([odpowiedzi tylko ze źródeł](../02-funkcje/01-czat/odpowiedzi-tylko-ze-zrodel.md)).

- **Ścieżka główna:** wymuszony format (`responseFormat` ze schematem JSON w `flutter_edge_ai`). Schemat ogranicza `type` do szablonów dozwolonych dla modelu, `target` do listy celów `map`, a `source_id` do identyfikatorów znalezionych fragmentów (`enum`). Bez narzędzi (tool calling) i bez trybu myślenia.
- **Zapas,** gdy Gemma 4 `.litertlm` na danym silniku nie wymusza formatu (`model.structuredOutputSupport`, `model.refusalFor(format)`): schemat w prompcie, tolerancyjny parser (wycina pierwszy obiekt `{…}`, ignoruje tekst wokół i płotki ```` ``` ````) i jedna ponowna próba. Druga porażka → tryb bez AI dla tej wiadomości.
- *Do sprawdzenia w bramce h2:* czy wymuszony format działa z Gemma 4 E2B `.litertlm` na telefonie demo.
- Odpowiedź nie jest parsowana w kawałkach: w trakcie generowania czat pokazuje szkielet, a szablony pojawiają się naraz po walidacji ([ekran czatu](../03-ekrany/ekran-1-czat.md#przepływ-po-wysłaniu-wiadomości)).

Przykład:

```json
{
  "panels": [
    {
      "type": "steps",
      "title": "Teraz",
      "items": [
        { "text": "…", "source_id": "poradnik-2025-s14-f3" }
      ]
    },
    { "type": "map", "target": "nearest_shelter" },
    { "type": "call" }
  ]
}
```

Kod odrzuca każdy krok, którego `source_id` nie istnieje albo którego treść nie pokrywa się z fragmentem.

## Kontekst w zapytaniu

- Znalezione fragmenty ze źródłem.
- Skrót profilu domu.
- Pozycja, kierunek, najbliższe punkty, poziom baterii, pora dnia.

## Tryb bez AI

Gdy model nie działa, czat pokazuje fragmenty źródeł bezpośrednio w panelach. Karty ratunkowe i plan 72 h nigdy nie zależą od modelu.
