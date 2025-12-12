import 'package:flutter/material.dart';
import 'dart:math' as math;


void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Element Polynomial (Photosynthesis Game)',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const ElementPolynomialPage(),
    );
  }
}

class ElementPolynomialPage extends StatefulWidget {
  const ElementPolynomialPage({super.key});

  @override
  State<ElementPolynomialPage> createState() => _ElementPolynomialPageState();
}

class _ElementPolynomialPageState extends State<ElementPolynomialPage> {
  // Expression inputs: dynamic list of terms (coeff + molecule). Null values allowed (blank rows).
  List<int?> _coeffs = [6, 6];
  List<String?> _mols = ['CO2', 'H2O'];
  final List<String> _moleculeOptions = [
    'CO2', 'H2O', 'C6H12O6', 'O2', 'H2', 'N2', 'Mg', 'Fe', 'K', 'Ca'
  ];
  final _constantController = TextEditingController(text: '1');

  // Operation fixed to addition only for final product
  Map<String, double> _combined = {};
  String _combinedStr = '';
  
  List<String> _deficiencies = [];
  String _moleculeRepresentation = '';


  @override
  void dispose() {
    // no controllers for expr1/expr2 anymore
    _constantController.dispose();
    super.dispose();
  }

  // removed unused helper: _showMessage

  // Parse a molecular formula like C6H12O6 into a map { 'C':6, 'H':12, 'O':6 }
  Map<String, int> parseMolecule(String s) {
    final res = <String, int>{};
    final regex = RegExp(r'([A-Z][a-z]?)(\d*)');
    for (final m in regex.allMatches(s)) {
      final el = m.group(1)!;
      final countStr = m.group(2);
      final count = (countStr == null || countStr.isEmpty) ? 1 : int.parse(countStr);
      res.update(el, (v) => v + count, ifAbsent: () => count);
    }
    return res;
  }

  // canonical signature for a molecule map: elements sorted alphabetically, like C6H12O6
  String moleculeSignature(Map<String, int> mol) {
    final keys = mol.keys.toList()..sort();
    final sb = StringBuffer();
    for (final k in keys) {
      final v = mol[k]!;
      sb.write(k);
      if (v != 1) sb.write(v);
    }
    return sb.toString();
  }

  // Parse an expression containing + / - terms. Terms can have optional numeric coefficient in front.
  // Examples: "2C6H12O6 + -0.5O2" or "C6H12O6+O2"
  Map<String, double> parseExpression(String s) {
    final res = <String, double>{};
    final input = s.replaceAll(' ', '');
    if (input.isEmpty) return res;

    // term regex: optional sign, optional numeric coeff, molecule (sequence of element tokens)
    final termRegex = RegExp(r'([+-]?)(\d*\.?\d*)?([A-Z][a-z]?\d*(?:[A-Z][a-z]?\d*)*)');
    final matches = termRegex.allMatches(input);
    for (final m in matches) {
      final whole = m.group(0);
      if (whole == null || whole.isEmpty) continue;
      final signStr = m.group(1) ?? '';
      final coeffStr = m.group(2) ?? '';
      final molStr = m.group(3) ?? '';
      if (molStr.isEmpty) continue;

      double coeff = 1.0;
      if (coeffStr.isNotEmpty) coeff = double.parse(coeffStr);
      if (signStr == '-') coeff = -coeff;

      // parse molecule and update signature coefficient
      final molMap = parseMolecule(molStr);
      final sig = moleculeSignature(molMap);
      res.update(sig, (old) => old + coeff, ifAbsent: () => coeff);
    }
    return res;
  }

  // Try to express a remainder element map as common simple molecules (e.g. O2, H2)
  // Falls back to element counts for leftovers.
  String formatRemainderAsMolecules(Map<String, double> remainder) {
    if (remainder.isEmpty) return '';
    // define simple molecule recipes to try (ordered)
    final List<Map<String, dynamic>> simple = [
      // Prefer water where possible (consumes H and O), then O2, then H2, then N2
      {'sig': 'H2O', 'map': {'H': 2, 'O': 1}},
      {'sig': 'O2', 'map': {'O': 2}},
      {'sig': 'H2', 'map': {'H': 2}},
      {'sig': 'N2', 'map': {'N': 2}},
    ];

    final rem = Map<String, double>.from(remainder);
    final parts = <String>[];

    for (final mol in simple) {
      final sig = mol['sig'] as String;
      final Map<String, int> need = Map<String, int>.from(mol['map'] as Map);
      // compute how many whole molecules we can form
      var maxCount = double.infinity;
      need.forEach((el, cnt) {
        final have = rem[el] ?? 0.0;
        maxCount = math.min(maxCount, have / cnt);
      });
      final whole = maxCount.isFinite ? maxCount.floor() : 0;
      if (whole > 0) {
        parts.add('$whole$sig');
        need.forEach((el, cnt) {
          rem.update(el, (v) => v - whole * cnt);
          if ((rem[el] ?? 0.0) <= 0) rem.remove(el);
        });
      }
    }

    // format any leftover elements using the existing formatter
    final leftoverSig = formatAggregatedCounts(rem);
    if (leftoverSig.isNotEmpty && leftoverSig != '—') {
      parts.add(leftoverSig);
    }

    if (parts.isEmpty) return '—';
    return parts.join(' + ');
  }

  // Aggregate element counts from an expression where keys are molecule signatures
  // and values are coefficients. Returns a map element -> total (double).
  Map<String, double> aggregateElementCounts(Map<String, double> expr) {
    final totals = <String, double>{};
    expr.forEach((sig, coeff) {
      if (coeff == 0) return;
      final mol = parseMolecule(sig);
      mol.forEach((el, cnt) {
        totals.update(el, (v) => v + coeff * cnt, ifAbsent: () => coeff * cnt);
      });
    });
    return totals;
  }

  // Simple deficiency check against a given recipe (defaults to glucose)
  List<String> checkDeficiencies(Map<String, double> aggregated, [Map<String, int>? recipe]) {
    final rec = recipe ?? {'C': 6, 'H': 12, 'O': 6};
    final misses = <String>[];
    rec.forEach((el, need) {
      final have = aggregated[el] ?? 0.0;
      if (have < need) {
        final short = (need - have).ceil();
        misses.add('$el: need $short more');
      }
    });
    return misses;
  }

  // Format aggregated element counts into a formula-like string
  String formatAggregatedCounts(Map<String, double> agg) {
    if (agg.isEmpty) return '—';
    final keys = agg.keys.toList()..sort();
    final sb = StringBuffer();
    for (final k in keys) {
      final v = agg[k]!;
      if (v == 0) continue;
      sb.write(k);
      // print integer counts without decimal when possible
      if ((v - v.round()).abs() < 1e-9) {
        final iv = v.round();
        if (iv != 1) sb.write(iv);
      } else {
        sb.write(v.toStringAsFixed(2));
      }
    }
    final out = sb.toString();
    return out.isEmpty ? '—' : out;
  }

  // Expression arithmetic on maps keyed by molecule signature
  Map<String, double> addExpr(Map<String, double> a, Map<String, double> b) {
    final res = Map<String, double>.from(a);
    b.forEach((k, v) => res.update(k, (old) => old + v, ifAbsent: () => v));
    res.removeWhere((k, v) => v == 0);
    return res;
  }

  // subtraction and multiplication helpers removed — operation is fixed to addition

  String formatExpression(Map<String, double> expr) {
    if (expr.isEmpty) return '—';
    final parts = <String>[];
    expr.forEach((sig, coeff) {
      if (coeff == 0) return;
      final coeffStr = (coeff == coeff.round()) ? coeff.round().toString() : coeff.toString();
      if (coeff == 1) {
        parts.add(sig);
      } else if (coeff == -1) {
        parts.add('-$sig');
      } else {
        parts.add('$coeffStr$sig');
      }
    });
    return parts.join(' + ').replaceAll('+ -', '- ');
  }

  // Compute how many whole target molecules (default glucose) can be made
  // and return a display string like '1 C6H12O6 + remainder: 6O2'
  String computeMoleculeRepresentation(Map<String, double> aggregated, [Map<String, int>? recipe]) {
    final rec = recipe ?? {'C': 6, 'H': 12, 'O': 6};
    if (aggregated.isEmpty) return '—';

    var maxWhole = double.infinity;
    rec.forEach((el, need) {
      final have = aggregated[el] ?? 0.0;
      maxWhole = math.min(maxWhole, have / need);
    });
    final whole = maxWhole.isFinite ? maxWhole.floor() : 0;
    final remainder = Map<String, double>.from(aggregated);
    if (whole > 0) {
      rec.forEach((el, need) {
    remainder.update(el, (v) => v - whole * need, ifAbsent: () => 0.0 - whole * need);
        if ((remainder[el] ?? 0.0) <= 0) remainder.remove(el);
      });
    }
    final remSig = formatRemainderAsMolecules(remainder);
  final recipeSig = moleculeSignature(rec);
    if (whole > 0) {
      if (remainder.isEmpty) return '$whole $recipeSig';
      return '$whole $recipeSig + remainder: $remSig';
    }
    return remSig;
  }

  // Combine button handler: only updates the combined expression string/state
  void _combine() {
    final expr = <String, double>{};
    for (var i = 0; i < _coeffs.length; i++) {
      final c = _coeffs[i];
      final m = _mols[i];
      if (c == null || m == null) continue;
      if (c == 0) continue;
      final sig = moleculeSignature(parseMolecule(m));
      expr.update(sig, (old) => old + c.toDouble(), ifAbsent: () => c.toDouble());
    }
    final out = expr;

    setState(() {
      _combined = out;
      _combinedStr = formatExpression(out);
      // clear evaluation outputs until Evaluate is pressed
      _deficiencies = [];
      _moleculeRepresentation = '';
    });
  }

  // Evaluate button handler: aggregates element counts and computes representation
  void _evaluate() {
    // If user didn't press Combine, derive combined from controllers
    if (_combined.isEmpty) _combine();
    final agg = aggregateElementCounts(_combined);
    final defs = checkDeficiencies(agg);
    final repr = computeMoleculeRepresentation(agg);
    setState(() {
      _deficiencies = defs;
      _moleculeRepresentation = repr;
      // aggregated string removed; keep molecule representation and deficiencies
    });
  }

  @override
  Widget build(BuildContext context) {
    // Choose background decoration depending on deficiencies (simplified game rule)
    final BoxDecoration backgroundDecoration;
    final Widget statusIcon;
    if (_combined.isNotEmpty && _deficiencies.isEmpty) {
      // success
      backgroundDecoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade300, Colors.green.shade100],
        ),
      );
      statusIcon = const Icon(Icons.wb_sunny, size: 48, color: Colors.white);
    } else if (_deficiencies.isNotEmpty) {
      backgroundDecoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade300, Colors.red.shade200],
        ),
      );
      statusIcon = const Icon(Icons.warning, size: 48, color: Colors.white);
    } else {
      backgroundDecoration = BoxDecoration(color: Colors.white);
      statusIcon = const Icon(
        Icons.filter_vintage,
        size: 48,
        color: Colors.green,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Photosynthesis — Element Polynomials')),
      body: Container(
        decoration: backgroundDecoration,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: const Text(
                      'Enter expressions using element symbols, e.g. C6H12O6, O2, H2O. You can include coefficients like 2C6H12O6 or -0.5O2.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  statusIcon,
                ],
              ),
              const SizedBox(height: 8),
              // Dynamic list of expression terms (coeff + molecule). Empty rows allowed.
              Column(
                children: [
                  for (var i = 0; i < _coeffs.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          DropdownButton<int?>(
                            value: _coeffs[i],
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('-')),
                              ...List.generate(13, (j) => DropdownMenuItem<int?>(value: j, child: Text(j.toString()))),
                            ],
                            onChanged: (v) => setState(() => _coeffs[i] = v),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String?>(
                            value: _mols[i],
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('-')),
                              ..._moleculeOptions.map((m) => DropdownMenuItem<String?>(value: m, child: Text(m))).toList(),
                            ],
                            onChanged: (v) => setState(() => _mols[i] = v),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => setState(() {
                              _coeffs.removeAt(i);
                              _mols.removeAt(i);
                            }),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add term'),
                      onPressed: () => setState(() {
                        _coeffs.add(null);
                        _mols.add(null);
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
                      Row(
                        children: [
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _combine,
                            child: const Text('Combine'),
                          ),
                        ],
                      ),
              const SizedBox(height: 16),
              const Text('Combined expression:'),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_combinedStr.isEmpty ? '—' : _combinedStr),
              ),
              const SizedBox(height: 12),
              if (_deficiencies.isNotEmpty) ...[
                const Text('Deficiencies:'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(255, 0, 0, 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _deficiencies.map((d) => Text('• $d')).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              const Text(
                'Evaluate combined expression (constant represents sunlight points):',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _constantController,
                        decoration: const InputDecoration(
                          labelText: 'constant (sunlight)',
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _evaluate,
                    child: const Text('Evaluate'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Chemical Sum: (target molecules + remainder)',
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_moleculeRepresentation.isEmpty ? '—' : _moleculeRepresentation),
              ),
              const SizedBox(height: 20),
              const Text('Notes:'),
              const SizedBox(height: 6),
              const Text(
                '- Use element symbols with optional counts, e.g. C6H12O6, H2O, Mg.',
              ),
              const Text(
                '- Coefficients allowed before formulas, e.g. 2C6H12O6 or -0.5O2.',
              ),
                      const Text(
                        '- Operation is addition only: inputs are summed element-wise.',
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
