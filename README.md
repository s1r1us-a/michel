# Flappy Bird – Flutter

Ein Flappy-Bird-Klon, komplett in Flutter geschrieben – ohne externe Pakete.
Die Grafik wird per `CustomPainter` gezeichnet, die Spielschleife läuft über
einen `Ticker`.

## Features

- Tippen lässt den Vogel flattern, Schwerkraft zieht ihn nach unten
- Zufällig platzierte Rohrpaare mit Kollisionserkennung
- Punktestand und Sessionrekord
- Scrollender Boden, Wolken, Flügel-/Neigungsanimation
- Haptisches Feedback bei Punkt und Aufprall
- Läuft auf Android, iOS, Web und Desktop

## Starten

Die plattformspezifischen Ordner (`android/`, `ios/`, …) sind nicht
eingecheckt. Einmalig im Projektordner generieren:

```bash
flutter create .
flutter pub get
flutter run
```

## Tests

```bash
flutter test
```

## Steuerung

| Aktion            | Eingabe            |
| ----------------- | ------------------ |
| Starten / Flattern | Tippen (oder Klick) |
| Neue Runde        | Nach Game Over tippen |
