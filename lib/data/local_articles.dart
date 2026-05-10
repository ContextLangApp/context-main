import '../models/article.dart';

const List<Article> localArticles = [
  Article(
    id: 'tech-01',
    topic: 'Technology',
    level: 'B1',
    title: 'Wie Technologie unseren Alltag verändert',
    readingTimeMinutes: 2,
    body:
        'Technologie ist ein wichtiger Teil unseres täglichen Lebens. '
        'Smartphones, Computer und das Internet haben die Art und Weise, '
        'wie wir arbeiten, kommunizieren und uns erholen, grundlegend verändert.\n\n'
        'Früher mussten Menschen in Bibliotheken gehen, um Informationen zu finden. '
        'Heute können wir alles mit einem Klick auf unserem Handy suchen. '
        'Das Internet gibt uns Zugang zu Wissen aus der ganzen Welt.\n\n'
        'Auch die Arbeitswelt hat sich verändert. Viele Menschen arbeiten jetzt '
        'von zu Hause aus – das nennt man „Homeoffice". Sie nutzen Programme wie '
        'Zoom oder Teams, um mit Kollegen zu sprechen. Das spart Zeit und Geld.\n\n'
        'Natürlich hat Technologie auch Nachteile. Manche Menschen verbringen zu '
        'viel Zeit mit ihren Smartphones. Das kann zu Stress und Schlafproblemen führen.\n\n'
        'Es ist wichtig, Technologie klug zu nutzen. Wir sollten digitale Werkzeuge '
        'als Hilfe sehen, nicht als Ersatz für echte menschliche Verbindungen.',
    vocabulary: [
      VocabItem(word: 'der Alltag', translation: 'everyday life'),
      VocabItem(word: 'das Homeoffice', translation: 'working from home'),
      VocabItem(word: 'das Werkzeug', translation: 'tool'),
      VocabItem(word: 'digital', translation: 'digital'),
      VocabItem(word: 'die Verbindung', translation: 'connection'),
      VocabItem(word: 'der Zugang', translation: 'access'),
    ],
  ),
  Article(
    id: 'sport-01',
    topic: 'Sport',
    level: 'B1',
    title: 'Sport und Gesundheit: Warum Bewegung wichtig ist',
    readingTimeMinutes: 2,
    body:
        'Sport ist wichtig für Körper und Geist. Regelmäßige Bewegung hilft dabei, '
        'gesund zu bleiben und Stress abzubauen. Viele Ärzte empfehlen, '
        'mindestens dreimal pro Woche Sport zu treiben.\n\n'
        'Es gibt viele verschiedene Sportarten. Manche Menschen laufen gerne '
        'im Park oder fahren Fahrrad. Andere spielen Fußball, Basketball oder Tennis. '
        'Schwimmen ist besonders gut für die Gelenke und den ganzen Körper.\n\n'
        'In Deutschland ist Fußball die beliebteste Sportart. Millionen von Menschen '
        'schauen regelmäßig Bundesliga-Spiele im Fernsehen oder gehen ins Stadion. '
        'Auch Sportvereine spielen eine große Rolle – fast jede Stadt hat einen Verein, '
        'dem man beitreten kann.\n\n'
        'Sport hat auch soziale Vorteile. Im Verein oder in der Gruppe lernt man neue '
        'Menschen kennen und arbeitet als Team zusammen.\n\n'
        'Wenn man lange keinen Sport gemacht hat, sollte man langsam beginnen. '
        'Ein kurzer Spaziergang jeden Tag ist ein guter Anfang. Das Wichtigste ist, '
        'dass man Spaß an der Bewegung hat und regelmäßig dabei bleibt.',
    vocabulary: [
      VocabItem(word: 'die Bewegung', translation: 'physical activity'),
      VocabItem(word: 'der Verein', translation: 'club'),
      VocabItem(word: 'die Gesundheit', translation: 'health'),
      VocabItem(word: 'das Gelenk', translation: 'joint'),
      VocabItem(word: 'beitreten', translation: 'to join'),
      VocabItem(word: 'regelmäßig', translation: 'regularly'),
    ],
  ),
  Article(
    id: 'food-01',
    topic: 'Food',
    level: 'B1',
    title: 'Die deutsche Küche: Traditionen und neue Trends',
    readingTimeMinutes: 2,
    body:
        'Die deutsche Küche ist für ihre Vielfalt bekannt. Traditionelle Gerichte '
        'wie Bratwurst, Sauerkraut und Kartoffelsuppe sind auf der ganzen Welt beliebt. '
        'Aber die deutsche Küche hat sich in den letzten Jahren stark verändert.\n\n'
        'Heute essen viele Deutsche gerne internationale Gerichte. '
        'Italienische Pizza, türkischer Döner und asiatische Nudeln sind sehr beliebt. '
        'In großen Städten wie Berlin oder München gibt es Restaurants aus fast allen Ländern.\n\n'
        'Gleichzeitig interessieren sich immer mehr Menschen für regionale und saisonale '
        'Produkte. Wochenmärkte sind wieder sehr beliebt. Dort kaufen die Menschen frisches '
        'Gemüse, Obst, Käse und Brot direkt vom Erzeuger.\n\n'
        'Ein wichtiger Trend ist auch die vegetarische und vegane Ernährung. '
        'Immer mehr Restaurants bieten pflanzliche Gerichte an. '
        'Viele Menschen möchten gesünder essen und gleichzeitig die Umwelt schonen.\n\n'
        'Das gemeinsame Essen ist in Deutschland ein wichtiger Teil der Kultur. '
        'Familien und Freunde treffen sich regelmäßig zum Abendessen und '
        'genießen die Zeit zusammen.',
    vocabulary: [
      VocabItem(word: 'die Küche', translation: 'cuisine / kitchen'),
      VocabItem(word: 'der Wochenmarkt', translation: 'weekly market'),
      VocabItem(word: 'saisonal', translation: 'seasonal'),
      VocabItem(word: 'der Erzeuger', translation: 'producer'),
      VocabItem(word: 'pflanzlich', translation: 'plant-based'),
      VocabItem(word: 'die Ernährung', translation: 'diet / nutrition'),
    ],
  ),
  Article(
    id: 'travel-01',
    topic: 'Travel',
    level: 'B1',
    title: 'Reisen in Deutschland: Die schönsten Ziele',
    readingTimeMinutes: 2,
    body:
        'Deutschland ist ein Land mit vielen wunderbaren Reisezielen. '
        'Von der Nordseeküste bis zu den Alpen gibt es viel zu entdecken. '
        'Städte wie Berlin, München, Hamburg und Köln ziehen jedes Jahr '
        'Millionen von Touristen an.\n\n'
        'Berlin ist die Hauptstadt und eine der aufregendsten Städte Europas. '
        'Das Brandenburger Tor, Museen und die lebendige Kunstszene machen '
        'die Stadt so besonders. München dagegen ist bekannt für das Oktoberfest, '
        'wunderschöne Kirchen und die Nähe zu den bayerischen Alpen.\n\n'
        'Auch die deutsche Natur ist beeindruckend. Der Schwarzwald, das Rheintal '
        'und die Ostseeküste sind beliebte Reiseziele für Naturfreunde. '
        'Viele Wanderwege führen durch herrliche Landschaften.\n\n'
        'Deutschland ist außerdem gut mit öffentlichen Verkehrsmitteln erreichbar. '
        'Mit dem Zug kommt man schnell und bequem von einer Stadt zur anderen.\n\n'
        'Egal ob Strand, Berge oder Großstadt – Deutschland hat für jeden '
        'Reisenden etwas zu bieten.',
    vocabulary: [
      VocabItem(word: 'das Reiseziel', translation: 'travel destination'),
      VocabItem(word: 'der Tourist', translation: 'tourist'),
      VocabItem(word: 'die Landschaft', translation: 'landscape'),
      VocabItem(word: 'der Wanderweg', translation: 'hiking trail'),
      VocabItem(word: 'das Verkehrsmittel', translation: 'means of transport'),
      VocabItem(word: 'bequem', translation: 'comfortable'),
    ],
  ),
  Article(
    id: 'science-01',
    topic: 'Science',
    level: 'B1',
    title: 'Klimawandel: Was können wir tun?',
    readingTimeMinutes: 2,
    body:
        'Der Klimawandel ist eines der wichtigsten Themen unserer Zeit. '
        'Die Erde wird wärmer, und das hat große Auswirkungen auf Mensch und Natur. '
        'Wissenschaftler aus aller Welt sind sich einig: Wir müssen jetzt handeln.\n\n'
        'Der Hauptgrund für den Klimawandel ist der Ausstoß von Treibhausgasen '
        'wie Kohlendioxid. Diese entstehen vor allem durch Kohle, Öl und Gas. '
        'Auch die Abholzung von Wäldern trägt zum Problem bei.\n\n'
        'Die Folgen sind bereits sichtbar. Extreme Wetterereignisse wie Überschwemmungen, '
        'Dürren und Stürme werden häufiger. Gletscher schmelzen, und der Meeresspiegel steigt.\n\n'
        'Aber es gibt auch Hoffnung. Erneuerbare Energien wie Solar- und Windkraft '
        'werden immer günstiger und effizienter. Viele Länder haben sich verpflichtet, '
        'weniger CO₂ auszustoßen.\n\n'
        'Jeder Einzelne kann ebenfalls einen Beitrag leisten: weniger Auto fahren, '
        'weniger Fleisch essen und bewusster einkaufen. Kleine Veränderungen '
        'können zusammen einen großen Unterschied machen.',
    vocabulary: [
      VocabItem(word: 'der Klimawandel', translation: 'climate change'),
      VocabItem(word: 'das Treibhausgas', translation: 'greenhouse gas'),
      VocabItem(word: 'die Überschwemmung', translation: 'flood'),
      VocabItem(word: 'erneuerbar', translation: 'renewable'),
      VocabItem(word: 'der Meeresspiegel', translation: 'sea level'),
      VocabItem(word: 'der Beitrag', translation: 'contribution'),
    ],
  ),
  Article(
    id: 'music-01',
    topic: 'Music',
    level: 'B1',
    title: 'Musik: Eine universelle Sprache',
    readingTimeMinutes: 2,
    body:
        'Musik begleitet uns durch das ganze Leben. Sie weckt Emotionen, '
        'verbindet Menschen und hilft uns, schwierige Momente zu überstehen. '
        'Ob Klassik, Pop, Jazz oder elektronische Musik – jeder findet seinen '
        'eigenen Geschmack.\n\n'
        'In Deutschland hat Musik eine lange Geschichte. Berühmte Komponisten '
        'wie Bach, Beethoven und Mozart prägten die klassische Musik. '
        'Ihre Werke werden bis heute in Konzertsälen auf der ganzen Welt aufgeführt.\n\n'
        'Auch die moderne Musikszene ist lebendig. Städte wie Berlin und Hamburg '
        'sind bekannt für ihre Clubs und Konzerte. Deutsche Künstler sind '
        'international erfolgreich.\n\n'
        'Musik hat wissenschaftlich nachgewiesene Vorteile. Sie kann Stress reduzieren, '
        'die Stimmung verbessern und beim Lernen helfen. Deshalb hören viele Menschen '
        'Musik beim Sport oder wenn sie sich entspannen möchten.\n\n'
        'Ein Instrument zu lernen hat ebenfalls viele Vorteile. '
        'Konzentration, Geduld und Kreativität werden durch Musizieren gestärkt. '
        'Es ist nie zu spät, mit einem neuen Instrument anzufangen.',
    vocabulary: [
      VocabItem(word: 'die Emotion', translation: 'emotion'),
      VocabItem(word: 'der Komponist', translation: 'composer'),
      VocabItem(word: 'das Werk', translation: 'work / composition'),
      VocabItem(word: 'die Stimmung', translation: 'mood'),
      VocabItem(word: 'die Kreativität', translation: 'creativity'),
      VocabItem(word: 'musizieren', translation: 'to make music'),
    ],
  ),
];

/// Returns the first article whose topic matches one of [favoriteTopics].
/// Falls back to the first article if no match is found.
Article articleForTopics(List<String> favoriteTopics) {
  for (final topic in favoriteTopics) {
    final index = localArticles.indexWhere((a) => a.topic == topic);
    if (index != -1) return localArticles[index];
  }
  return localArticles.first;
}
