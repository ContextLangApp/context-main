import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  int _page = 0;

  final _nameController = TextEditingController();
  String? _learningReason;
  final _selectedTopics = <String>{};
  bool _isLoading = false;

  static const _reasons = [
    'Advancing my career',
    'Learning new skills',
    'Supporting education',
    'Personal interest',
    'Travel',
    'Connecting with family or friends',
  ];

  static const _topics = [
    'Books',
    'Art & Design',
    'Sport',
    'Technology',
    'Food',
    'Music',
    'Travel',
    'Science',
    'History',
    'Business',
    'Film & TV',
    'Gaming',
  ];

  bool get _canContinue {
    switch (_page) {
      case 0:
        return _nameController.text.trim().isNotEmpty;
      case 1:
        return _learningReason != null;
      case 2:
        return _selectedTopics.isNotEmpty;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_page > 0) {
      setState(() => _page--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goNext() {
    if (_page < 2) {
      setState(() => _page++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveAndFinish();
    }
  }

  Future<void> _saveAndFinish() async {
    setState(() => _isLoading = true);
    try {
      // Upsert (not insert) so a pre-existing or partial profile row — e.g.
      // from an interrupted run or a signup trigger — doesn't dead-end
      // onboarding with a duplicate-key error.
      await Supabase.instance.client.from('profiles').upsert({
        'id': Supabase.instance.client.auth.currentUser!.id,
        'name': _nameController.text.trim(),
        'learning_reason': _learningReason,
        'favorite_topics': _selectedTopics.toList(),
      });
      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Row(
                children: [
                  if (_page > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _goBack,
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  Text(
                    '${_page + 1} of 3',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: (_page + 1) / 3,
              minHeight: 3,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF8B5CF6),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _NamePage(controller: _nameController),
                  _ReasonPage(
                    selected: _learningReason,
                    reasons: _reasons,
                    onSelect: (r) => setState(() => _learningReason = r),
                  ),
                  _TopicsPage(
                    selected: _selectedTopics,
                    topics: _topics,
                    onToggle: (topic) {
                      setState(() {
                        if (_selectedTopics.contains(topic)) {
                          _selectedTopics.remove(topic);
                        } else if (_selectedTopics.length < 5) {
                          _selectedTopics.add(topic);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: ElevatedButton(
                onPressed: (_canContinue && !_isLoading) ? _goNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFB8C4E0),
                  disabledForegroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _page == 2 ? 'Finish' : 'Continue',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NamePage extends StatelessWidget {
  const _NamePage({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            "What's your name?",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'This is how we\'ll greet you in the app.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Your name',
              hintStyle: TextStyle(color: Colors.black38),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonPage extends StatelessWidget {
  const _ReasonPage({
    required this.selected,
    required this.reasons,
    required this.onSelect,
  });

  final String? selected;
  final List<String> reasons;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Why do you want to\nlearn German?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ...reasons.map((reason) {
            final isSelected = reason == selected;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onSelect(reason),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TopicsPage extends StatelessWidget {
  const _TopicsPage({
    required this.selected,
    required this.topics,
    required this.onToggle,
  });

  final Set<String> selected;
  final List<String> topics;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Pick your favorite topics',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            selected.length == 5
                ? 'Maximum reached (5 of 5)'
                : 'Choose up to 5  •  ${selected.length} selected',
            style: TextStyle(
              fontSize: 16,
              color: selected.length == 5
                  ? const Color(0xFF8B5CF6)
                  : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: topics.map((topic) {
              final isSelected = selected.contains(topic);
              final isDisabled = !isSelected && selected.length >= 5;
              return GestureDetector(
                onTap: isDisabled ? null : () => onToggle(topic),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : isDisabled
                            ? const Color(0xFFF5F5F5)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    topic,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : isDisabled
                              ? Colors.black26
                              : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
