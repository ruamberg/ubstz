import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(UbstzApp());
}

class UbstzApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ubstz',
      home: FlashcardPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Word {
  final String word;
  final String? article;
  final String? plural;
  final String? translationPt;

  Word({
    required this.word,
    this.article,
    this.plural,
    this.translationPt,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      word: json['word'],
      article: json['article'],
      plural: json['plural'],
      translationPt: json['translation_pt'],
    );
  }
}

class Flashcard {
  final Word word;
  final String question;
  final String answer;

  Flashcard({
    required this.word,
    required this.question,
    required this.answer,
  });
}

class FlashcardPage extends StatefulWidget {
  @override
  _FlashcardPageState createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage>
    with TickerProviderStateMixin {
  List<Word> words = [];
  Flashcard? currentCard;
  Flashcard? nextCard;
  bool showAnswer = false;
  int correctCount = 0;
  int incorrectCount = 0;

  final List<String> questions = [
    'Qual o artigo da palavra?',
    'Qual o plural da palavra?',
    'Qual a tradução da palavra?',
  ];

  double _cardOffsetX = 0.0;
  double _cardRotation = 0.0;

  Color _backgroundColor = Colors.black; // Cor de fundo inicial

  @override
  void initState() {
    super.initState();
    loadWords();
    loadScore();
  }

  Future<void> loadWords() async {
    final String response = await rootBundle.loadString('assets/words.json');
    final data = await json.decode(response) as List;
    setState(() {
      words = data.map((wordData) => Word.fromJson(wordData)).toList();
      prepareNextCards();
    });
  }

  void prepareNextCards() {
    currentCard = generateFlashcard();
    nextCard = generateFlashcard();
    showAnswer = false;
  }

  Flashcard generateFlashcard() {
    final random = Random();

    Word word = words[random.nextInt(words.length)];
    String question = '';
    String answer = '';

    // Lista de perguntas possíveis para a palavra atual
    List<String> availableQuestions = [];

    if (word.article != null && word.article!.isNotEmpty) {
      availableQuestions.add('Qual o artigo da palavra?');
    }
    if (word.plural != null && word.plural!.isNotEmpty) {
      availableQuestions.add('Qual o plural da palavra?');
    }
    if (word.translationPt != null && word.translationPt!.isNotEmpty) {
      availableQuestions.add('Qual a tradução da palavra?');
    }

    // Se não houver perguntas disponíveis, selecionar outra palavra
    while (availableQuestions.isEmpty) {
      word = words[random.nextInt(words.length)];
      availableQuestions.clear();

      if (word.article != null && word.article!.isNotEmpty) {
        availableQuestions.add('Qual o artigo da palavra?');
      }
      if (word.plural != null && word.plural!.isNotEmpty) {
        availableQuestions.add('Qual o plural da palavra?');
      }
      if (word.translationPt != null && word.translationPt!.isNotEmpty) {
        availableQuestions.add('Qual a tradução da palavra?');
      }
    }

    // Selecionar uma pergunta disponível aleatoriamente
    question = availableQuestions[random.nextInt(availableQuestions.length)];

    // Definir a resposta com base na pergunta selecionada
    switch (question) {
      case 'Qual o artigo da palavra?':
        answer = word.article!;
        break;
      case 'Qual o plural da palavra?':
        answer = word.plural!;
        break;
      case 'Qual a tradução da palavra?':
        answer = word.translationPt!;
        break;
    }

    return Flashcard(
      word: word,
      question: question,
      answer: answer,
    );
  }

  Future<void> loadScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      correctCount = prefs.getInt('correct') ?? 0;
      incorrectCount = prefs.getInt('incorrect') ?? 0;
    });
  }

  Future<void> updateScore(bool isCorrect) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (isCorrect) {
        correctCount++;
        prefs.setInt('correct', correctCount);
      } else {
        incorrectCount++;
        prefs.setInt('incorrect', incorrectCount);
      }
    });
  }

  void onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _cardOffsetX += details.delta.dx;
      _cardRotation = _cardOffsetX / 300;
    });
  }

  void onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    if (_cardOffsetX > screenWidth * 0.25) {
      // Swipe para a direita (errou)
      updateScore(false);
      setState(() {
        _backgroundColor = Colors.red;
      });
      // Retorna ao preto após um tempo
      Future.delayed(Duration(milliseconds: 500), () {
        setState(() {
          _backgroundColor = Colors.black;
        });
      });
      animateCardOffScreen(screenWidth);
    } else if (_cardOffsetX < -screenWidth * 0.25) {
      // Swipe para a esquerda (acertou)
      updateScore(true);
      setState(() {
        _backgroundColor = Colors.green;
      });
      // Retorna ao preto após um tempo
      Future.delayed(Duration(milliseconds: 500), () {
        setState(() {
          _backgroundColor = Colors.black;
        });
      });
      animateCardOffScreen(-screenWidth);
    } else {
      // Retorna ao centro
      setState(() {
        _cardOffsetX = 0;
        _cardRotation = 0;
      });
    }
  }

  void animateCardOffScreen(double endX) {
    // Anima o card para fora da tela
    AnimationController controller = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    Animation<double> animation = Tween<double>(
      begin: _cardOffsetX,
      end: endX,
    ).animate(controller);

    animation.addListener(() {
      setState(() {
        _cardOffsetX = animation.value;
        _cardRotation = _cardOffsetX / 300;
      });
    });

    controller.forward().whenComplete(() {
      // Atualiza os cards
      setState(() {
        currentCard = nextCard;
        nextCard = generateFlashcard();
        _cardOffsetX = 0;
        _cardRotation = 0;
        showAnswer = false;
      });
      controller.dispose();
    });
  }

  // Método para resetar a pontuação
  void resetScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      correctCount = 0;
      incorrectCount = 0;
      prefs.setInt('correct', correctCount);
      prefs.setInt('incorrect', incorrectCount);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pontuação zerada!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentCard == null || nextCard == null) {
      return Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onLongPress: resetScore,
            child: Text('ubstz'),
          ),
          backgroundColor: Colors.black,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: resetScore,
          child: Text('ubstz'),
        ),
        backgroundColor: Colors.black,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Acertos: $correctCount  Erros: $incorrectCount',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: Duration(milliseconds: 500),
        color: _backgroundColor,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Próximo card
              buildCard(nextCard!, scale: 0.95, offsetY: 20),
              // Card atual
              Transform.translate(
                offset: Offset(_cardOffsetX, 0),
                child: Transform.rotate(
                  angle: _cardRotation * 0.5,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        showAnswer = true;
                      });
                    },
                    onPanUpdate: onPanUpdate,
                    onPanEnd: onPanEnd,
                    child: buildCard(currentCard!),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ... [o restante do código permanece o mesmo até a função buildCard]

  Widget buildCard(Flashcard card, {double scale = 1.0, double offsetY = 0.0}) {
    // Determinar outras respostas disponíveis
    List<Widget> otherAnswers = [];

    // Artigo
    if (card.word.article != null &&
        card.word.article!.isNotEmpty &&
        card.question != 'Qual o artigo da palavra?') {
      otherAnswers.add(
        Text(
          'Artigo: ${card.word.article}',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // Plural
    if (card.word.plural != null &&
        card.word.plural!.isNotEmpty &&
        card.question != 'Qual o plural da palavra?') {
      otherAnswers.add(
        Text(
          'Plural: ${card.word.plural}',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // Tradução
    if (card.word.translationPt != null &&
        card.word.translationPt!.isNotEmpty &&
        card.question != 'Qual a tradução da palavra?') {
      otherAnswers.add(
        Text(
          'Tradução: ${card.word.translationPt}',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Transform.scale(
      scale: scale,
      child: Transform.translate(
        offset: Offset(0, offsetY),
        child: Card(
          color: Colors.white, // Cor do card para contraste
          elevation: 4,
          margin: EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              // Alinhar à esquerda
              children: [
                Text(
                  card.word.word,
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                SizedBox(height: 16),
                Text(
                  card.question,
                  style: TextStyle(fontSize: 24, color: Colors.black),
                ),
                SizedBox(height: 16),
                if (showAnswer && card == currentCard)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.answer,
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                            color: Colors.black),
                      ),
                      SizedBox(height: 16),
                      ...otherAnswers,
                    ],
                  ),
                if (!showAnswer && card == currentCard)
                  Text(
                    'Toque para ver a resposta',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}