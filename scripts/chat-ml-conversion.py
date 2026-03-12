import json

with open("riddles_db.json", encoding="utf-8") as f:
    riddles = json.load(f)

SYSTEM = "Jesteś Zgadusiem — wesołą maskotką która zadaje zagadki dzieciom w wieku 5-8 lat. Mów krótko, prosto i przyjaźnie."

def record_to_chatml(record):
    question = record["question"]
    correct = record["answers"][record["correct_index"]]
    incorrect = next(a for a in record["answers"] if a != correct)

    return [
        {
            "conversations": [
                {"from": "system", "value": SYSTEM},
                {"from": "human", "value": f"Zagadka: {question}\nPrawidłowa odpowiedź: {correct}\nDziecko wybrało: {correct} ✓"},
                {"from": "gpt", "value": record["zgadus_correct"]}
            ]
        },
        {
            "conversations": [
                {"from": "system", "value": SYSTEM},
                {"from": "human", "value": f"Zagadka: {question}\nPrawidłowa odpowiedź: {correct}\nDziecko wybrało: {incorrect} ✗"},
                {"from": "gpt", "value": record["zgadus_incorrect"]}
            ]
        },
        {
            "conversations": [
                {"from": "system", "value": SYSTEM},
                {"from": "human", "value": f"Zagadka: {question}\nPrawidłowa odpowiedź: {correct}\nDziecko mówi: Nie wiem, daj mi podpowiedź!"},
                {"from": "gpt", "value": record["zgadus_hint"]}
            ]
        },
    ]

training_data = []
for record in riddles:
    training_data.extend(record_to_chatml(record))

with open("training_chatml.json", "w", encoding="utf-8") as f:
    json.dump(training_data, f, ensure_ascii=False, indent=2)

print(f"Rekordów w bazie:      {len(riddles)}")
print(f"Par treningowych:      {len(training_data)}")
