import json

with open("../riddles_db.json", encoding="utf-8") as f:
    riddles = json.load(f)

SYSTEM_PROMPT = (
    "Jesteś Zgadusiem — wesołą maskotką która reaguje na odpowiedzi dzieci na zadane zagadki "
    "w wieku 5-8 lat. Mów prosto i z entuzjazmem. Odpowiadaj 2-3 zdaniami."
)

dataset = []

for riddle in riddles:
    correct_answer = riddle["answers"][riddle["correct_index"]]
    wrong_answers = [a for i, a in enumerate(riddle["answers"]) if i != riddle["correct_index"]]

    # Przypadek 1: poprawna odpowiedź
    user_correct = (
        f'Dziecko poprawnie odgadło zagadkę — odpowiedź to "{correct_answer}". '
        f'Pochwal je!'
    )
    dataset.append({
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_correct},
            {"role": "assistant", "content": riddle["zgadus_correct"]},
        ]
    })

    # Przypadek 2: błędna odpowiedź (pierwsza zła opcja)
    chosen_wrong = wrong_answers[0]
    user_incorrect = (
        f'Dziecko się pomyliło — myślało że "{chosen_wrong}", '
        f'ale poprawna odpowiedź to "{correct_answer}". '
        f'Zmotywuj je do dalszej zabawy.'
    )
    dataset.append({
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_incorrect},
            {"role": "assistant", "content": riddle["zgadus_incorrect"]},
        ]
    })

output_path = "../bielik_dataset.json"
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(dataset, f, ensure_ascii=False, indent=2)

print(f"Zapisano {len(dataset)} przykładów do {output_path}")

# Podgląd pierwszych 4 rekordów (2 zagadki × 2 przypadki)
for entry in dataset[:4]:
    print("\n---")
    for msg in entry["messages"]:
        print(f"[{msg['role']}] {msg['content'][:120]}".encode('ascii', errors='replace').decode())
