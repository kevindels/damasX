import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const DamasApp());
}

class DamasApp extends StatelessWidget {
  const DamasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Damas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                width: 120,
                height: 120,
                child: const Icon(
                  Icons.sports_esports,
                  color: Colors.white,
                  size: 80,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Damas',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Juega contra la máquina!',
              style: TextStyle(fontSize: 20, color: Colors.black54),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                textStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                elevation: 8,
              ),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const DamasHomePage()),
                );
              },
              child: const Text('Jugar'),
            ),
          ],
        ),
      ),
    );
  }
}

class DamasHomePage extends StatefulWidget {
  const DamasHomePage({super.key});

  @override
  State<DamasHomePage> createState() => _DamasHomePageState();
}

enum PieceType { none, player, ai, playerKing, aiKing }

class _DamasHomePageState extends State<DamasHomePage> {
  static const int boardSize = 8;
  late List<List<PieceType>> board;
  bool playerTurn = true;
  int selectedRow = -1;
  int selectedCol = -1;
  bool gameOver = false;
  String winner = '';
  late final AudioPlayer _audioPlayer;
  bool _showWinAnim = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initBoard();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(String name) async {
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource('sounds/$name.mp3'), volume: 0.7);
  }

  void _initBoard() {
    board = List.generate(
      boardSize,
      (row) => List.generate(boardSize, (col) {
        if (row < 3 && (row + col) % 2 == 1) return PieceType.ai;
        if (row > 4 && (row + col) % 2 == 1) return PieceType.player;
        return PieceType.none;
      }),
    );
    playerTurn = true;
    selectedRow = -1;
    selectedCol = -1;
    gameOver = false;
    winner = '';
    _showWinAnim = false;
    setState(() {});
  }

  void _selectCell(int row, int col) {
    if (gameOver) return;
    if (!playerTurn) return;
    if (board[row][col] == PieceType.player ||
        board[row][col] == PieceType.playerKing) {
      setState(() {
        selectedRow = row;
        selectedCol = col;
      });
    } else if (selectedRow != -1 && selectedCol != -1) {
      _tryMove(selectedRow, selectedCol, row, col);
    }
  }

  void _tryMove(int fromRow, int fromCol, int toRow, int toCol) async {
    final piece = board[fromRow][fromCol];
    if (!_isValidMove(fromRow, fromCol, toRow, toCol, piece, true)) return;
    bool isCapture = (toRow - fromRow).abs() == 2;
    setState(() {
      board[toRow][toCol] = board[fromRow][fromCol];
      board[fromRow][fromCol] = PieceType.none;
      // Promoción a dama
      if (piece == PieceType.player && toRow == 0) {
        board[toRow][toCol] = PieceType.playerKing;
      }
      if (isCapture) {
        int capRow = (fromRow + toRow) ~/ 2;
        int capCol = (fromCol + toCol) ~/ 2;
        board[capRow][capCol] = PieceType.none;
      }
      selectedRow = -1;
      selectedCol = -1;
      playerTurn = false;
    });
    await _playSound(isCapture ? 'capture' : 'move');
    _checkGameOver();
    if (!gameOver) {
      Future.delayed(const Duration(milliseconds: 600), _aiMove);
    }
  }

  bool _isValidMove(
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
    PieceType piece,
    bool isPlayer,
  ) {
    if (toRow < 0 || toRow >= boardSize || toCol < 0 || toCol >= boardSize)
      return false;
    if (board[toRow][toCol] != PieceType.none) return false;
    int dir = isPlayer ? -1 : 1;
    if (piece == PieceType.player || piece == PieceType.ai) {
      if (toRow - fromRow == dir && (toCol - fromCol).abs() == 1) return true;
      if (toRow - fromRow == 2 * dir && (toCol - fromCol).abs() == 2) {
        int capRow = (fromRow + toRow) ~/ 2;
        int capCol = (fromCol + toCol) ~/ 2;
        if (isPlayer &&
            (board[capRow][capCol] == PieceType.ai ||
                board[capRow][capCol] == PieceType.aiKing))
          return true;
        if (!isPlayer &&
            (board[capRow][capCol] == PieceType.player ||
                board[capRow][capCol] == PieceType.playerKing))
          return true;
      }
    }
    if (piece == PieceType.playerKing || piece == PieceType.aiKing) {
      if ((toRow - fromRow).abs() == 1 && (toCol - fromCol).abs() == 1)
        return true;
      if ((toRow - fromRow).abs() == 2 && (toCol - fromCol).abs() == 2) {
        int capRow = (fromRow + toRow) ~/ 2;
        int capCol = (fromCol + toCol) ~/ 2;
        if (isPlayer &&
            (board[capRow][capCol] == PieceType.ai ||
                board[capRow][capCol] == PieceType.aiKing))
          return true;
        if (!isPlayer &&
            (board[capRow][capCol] == PieceType.player ||
                board[capRow][capCol] == PieceType.playerKing))
          return true;
      }
    }
    return false;
  }

  Future<void> _aiMove() async {
    if (gameOver) return;
    List<_Move> moves = [];
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] == PieceType.ai || board[r][c] == PieceType.aiKing) {
          for (int dr = -2; dr <= 2; dr++) {
            for (int dc = -2; dc <= 2; dc++) {
              if (dr.abs() == dc.abs() && dr != 0) {
                int nr = r + dr;
                int nc = c + dc;
                if (_isValidMove(r, c, nr, nc, board[r][c], false)) {
                  moves.add(_Move(r, c, nr, nc));
                }
              }
            }
          }
        }
      }
    }
    if (moves.isEmpty) {
      playerTurn = true;
      _checkGameOver();
      setState(() {});
      return;
    }
    moves.sort((a, b) => ((a.toRow - a.fromRow).abs() == 2 ? -1 : 1));
    final move = moves.first;
    final isCapture = (move.toRow - move.fromRow).abs() == 2;
    setState(() {
      final piece = board[move.fromRow][move.fromCol];
      board[move.toRow][move.toCol] = piece;
      board[move.fromRow][move.fromCol] = PieceType.none;
      if (piece == PieceType.ai && move.toRow == boardSize - 1) {
        board[move.toRow][move.toCol] = PieceType.aiKing;
      }
      if (isCapture) {
        int capRow = (move.fromRow + move.toRow) ~/ 2;
        int capCol = (move.fromCol + move.toCol) ~/ 2;
        board[capRow][capCol] = PieceType.none;
      }
      playerTurn = true;
    });
    await _playSound(isCapture ? 'capture' : 'move');
    _checkGameOver();
  }

  void _checkGameOver() async {
    int playerPieces = 0, aiPieces = 0;
    for (var row in board) {
      for (var cell in row) {
        if (cell == PieceType.player || cell == PieceType.playerKing)
          playerPieces++;
        if (cell == PieceType.ai || cell == PieceType.aiKing) aiPieces++;
      }
    }
    if (playerPieces == 0) {
      gameOver = true;
      winner = '¡La máquina gana!';
      _showWinAnim = true;
      await _playSound('lose');
      setState(() {});
    } else if (aiPieces == 0) {
      gameOver = true;
      winner = '¡Tú ganas!';
      _showWinAnim = true;
      await _playSound('win');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Damas'),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initBoard,
            tooltip: 'Reiniciar',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (gameOver && _showWinAnim)
              AnimatedVictory(
                winner: winner,
                onEnd: () => setState(() => _showWinAnim = false),
              ),
            if (!gameOver || !_showWinAnim) ...[
              if (gameOver)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    winner,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              _buildBoard(),
              const SizedBox(height: 24),
              Text(
                playerTurn ? 'Tu turno' : 'Turno de la máquina',
                style: TextStyle(
                  fontSize: 20,
                  color: playerTurn ? Colors.blue : Colors.redAccent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.brown, width: 4),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(boardSize, (row) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(boardSize, (col) {
              final isDark = (row + col) % 2 == 1;
              final isSelected = row == selectedRow && col == selectedCol;
              return GestureDetector(
                onTap: () => _selectCell(row, col),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? (isSelected ? Colors.amber : Colors.brown[400])
                        : Colors.brown[100],
                    border: isSelected
                        ? Border.all(color: Colors.amber, width: 3)
                        : null,
                  ),
                  child: _buildPiece(row, col),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildPiece(int row, int col) {
    final piece = board[row][col];
    if (piece == PieceType.none) return const SizedBox.shrink();
    Color color;
    bool isKing = false;
    if (piece == PieceType.player)
      color = Colors.blueAccent;
    else if (piece == PieceType.ai)
      color = Colors.redAccent;
    else if (piece == PieceType.playerKing) {
      color = Colors.blueAccent;
      isKing = true;
    } else {
      color = Colors.redAccent;
      isKing = true;
    }
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
          if (isKing) Icon(Icons.star, color: Colors.yellow[700], size: 18),
        ],
      ),
    );
  }
}

class AnimatedVictory extends StatefulWidget {
  final String winner;
  final VoidCallback onEnd;
  const AnimatedVictory({required this.winner, required this.onEnd, super.key});

  @override
  State<AnimatedVictory> createState() => _AnimatedVictoryState();
}

class _AnimatedVictoryState extends State<AnimatedVictory>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1800), widget.onEnd);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: Colors.amber[700], size: 64),
              const SizedBox(height: 16),
              Text(
                widget.winner,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Move {
  final int fromRow, fromCol, toRow, toCol;
  _Move(this.fromRow, this.fromCol, this.toRow, this.toCol);
}
