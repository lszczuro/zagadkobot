import json
import os
import random
from google import genai
from google.genai import types
from dotenv import load_dotenv

load_dotenv()

# Klient pobierze klucz automatycznie ze zmiennej środowiskowej GEMINI_API_KEY
client = genai.Client()

SYSTEM_PROMPT = """Jesteś generatorem bazy danych zagadek dla polskiej aplikacji edukacyjnej dla dzieci w wieku 5-8 lat.

Twoje zadanie to tworzenie kompletnych rekordów zagadek zawierających:
- treść zagadki
- jedną poprawną i dwie błędne odpowiedzi
- reakcje maskotki Zgadusia na każdy scenariusz

Zasady tworzenia zagadki:
- Treść prosta, max 2 zdania
- Odpowiedź jednoznaczna, nie opiera się na grze słów
- Dwie błędne odpowiedzi muszą być z tej samej kategorii co poprawna
  (np. jeśli odpowiedź to "Kot" → błędne to też zwierzęta, nie "Samochód")
- Błędne odpowiedzi powinny być wiarygodne — nie zbyt oczywiste
- correct_index zawsze 0 — aplikacja sama losuje kolejność wyświetlania

Zasady reakcji Zgadusia:
- Zgaduś to wesoła maskotka, mówi prosto, ciepło i z entuzjazmem
- Używa zdrobnień i okrzyków ("Brawo!", "Ojej!", "Super!")
- Max 2 zdania na każdą reakcję
- Używa emoji oszczędnie: max 1-2 na reakcję
- Nigdy nie mów "model", "AI", "program"
- zgadus_incorrect: NIE używaj słów "źle/błąd/niepoprawnie" — naprowadź wskazówką
- zgadus_hint: NIE zdradzaj odpowiedzi wprost

Zwróć TYLKO obiekt JSON, bez komentarzy, bez markdown."""

CATEGORIES = [
    "zwierzęta",
    "przyroda",
    "kosmos",
    "pojazdy"
]

DIFFICULTIES = ["łatwa", "średnia", "trudna"]

USER_PROMPT_TEMPLATE = """
Wygeneruj kompletny rekord zagadki.

Kategoria: {category}
Poziom trudności: {difficulty}

WAŻNE: Unikaj powtarzania tematów! 
Poprawną odpowiedzią NIE MOŻE BYĆ nic z poniższej listy, ponieważ mamy to już w bazie:
[{existing_answers}]

Zwróć TYLKO ten obiekt JSON:
{{
  "category": "string",
  "difficulty": "łatwa|średnia|trudna",
  "question": "string",
  "answers": ["poprawna", "błędna_1", "błędna_2"],
  "correct_index": 0,
  "zgadus_correct": "string",
  "zgadus_incorrect": "string",
  "zgadus_hint": "string"
}}
"""

def generate_riddle(category: str, difficulty: str, item_index: int, existing_answers: list) -> dict:
    existing_str = ", ".join(existing_answers) if existing_answers else "Brak (To pierwsza zagadka!)"
    
    prompt = USER_PROMPT_TEMPLATE.format(
        category=category,
        difficulty=difficulty,
        existing_answers=existing_str
    )

    response = client.models.generate_content(
        model='gemini-2.5-flash',
        contents=prompt,
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            # max_output_tokens=500, # zwiększono lub po prostu usunięto
            temperature=0.7, # Możesz podnieść temperaturę, jeśli chcesz bardziej oryginalne podejście modelów do wierszyków
            response_mime_type="application/json", 
        )
    )

    raw = response.text.strip()
    record = json.loads(raw)
    
    record["id"] = f"{category.replace(' ', '_')}_{item_index:04d}"
    return record


DB_FILE = "riddles_db.json"

if os.path.exists(DB_FILE):
    with open(DB_FILE, "r", encoding="utf-8") as f:
        try:
            dataset = json.load(f)
            print(f"Wczytano {len(dataset)} istniejących zagadek z bazy.")
        except json.JSONDecodeError:
            dataset = []
else:
    dataset = []

initial_count = len(dataset)
TARGET = 50

for category in CATEGORIES:
    for i in range(TARGET):
        difficulty = random.choice(DIFFICULTIES)
        
        # Pobierz dotychczasowe poprawne odpowiedzi dla TEY kategorii z bazy
        existing_for_category = [
            r["answers"][0] for r in dataset 
            if r.get("category") == category and "answers" in r
        ]
        
        try:
            record = generate_riddle(category, difficulty, len(dataset), existing_for_category)
            dataset.append(record)
            print(f"[{category}] {i+1}/{TARGET} ✓")
        except Exception as e:
            print(f"[{category}] {i+1}/{TARGET} BŁĄD: {e}")
            
with open(DB_FILE, "w", encoding="utf-8") as f:
    json.dump(dataset, f, ensure_ascii=False, indent=2)

new_count = len(dataset) - initial_count
print(f"\nWygenerowano i dodano {new_count} nowych rekordów. Łącznie w bazie: {len(dataset)}")
