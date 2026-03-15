from gguf import GGUFReader

reader = GGUFReader('assets/models/llm/Bielik-1.5B-v3.0-Instruct.Q4_K_M.gguf')
for field in reader.fields.values():
    if 'chat_template' in field.name:
        # parts zawiera bajty — dekodujemy do stringa
        for part in field.parts:
            try:
                print(bytes(part).decode('utf-8'))
            except Exception:
                print(part)
