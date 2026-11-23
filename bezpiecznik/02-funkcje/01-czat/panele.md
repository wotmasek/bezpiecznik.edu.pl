# Panele w czacie

**Priorytet:** P0 · **Gdzie:** odpowiedzi w czacie · **Offline:** tak

## Co robi

Odpowiedź Bezpiecznika nie jest ścianą tekstu, tylko zestawem gotowych paneli. Model wybiera panele z zamkniętej listy i wypełnia je treścią ze źródeł.

## Typy paneli

| Panel | Zawartość | Przykład |
|---|---|---|
| `steps` | Numerowane kroki po kolei (lista jak w ChatGPT, bez odhaczania, długa lista zwinięta) | Co zrobić w pierwszej godzinie blackoutu |
| `bullets` | Lista punktowana bez kolejności | Czego nie robić przy powodzi |
| `todo` | Lista do odhaczenia, tylko do przygotowań | Co spakować do plecaka |
| `form` | 1–3 pytania wyboru przed odpowiedzią | „Kto mieszka w domu?” przed planem na brak prądu |
| `map` | Miniatura mapy z najbliższym punktem, odległością i przyciskiem „Prowadź” | Najbliższy schron 450 m |
| `animation` | Krótka animacja (GIF) | Ułożenie dłoni przy RKO |
| `call` | Jeden przycisk „Zadzwoń 112” przypięty nad polem wpisywania | Po opisie wypadku |
| `signal` | Dźwięk SOS, latarka, stroboskop | Zagubienie w terenie |
| `quote` | Cytat, dokument, strona, data wydania; okno PDF z podświetlonym fragmentem, do rozwinięcia na pełny ekran | Osobny szablon pod odpowiedzią; kroki mają tylko przypisy [n] i listę „Źródła · n” |
| `cpr` | Instruktor RKO przypięty nad polem wiadomości na czas działania | „Ktoś nie oddycha” |

Wygląd i pola: [../../03-ekrany/szablony-czatu.md](../../03-ekrany/szablony-czatu.md)

## Zasady

- Każdy panel z treścią ma co najmniej jedno źródło.
- Panel `call` pojawia się zawsze, gdy sytuacja może zagrażać życiu.
- Kroki są krótkie: jeden czasownik, jedna czynność.
- Panele działają też w [trybie bez AI](czat.md#tryb-bez-ai), wypełnione bezpośrednio fragmentami źródeł.
