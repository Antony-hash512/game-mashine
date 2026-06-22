#!/usr/bin/env python3
import os
import sys
import re
import json
import xml.etree.ElementTree as ET

# Константы для сетки спрайтов
CELL_W = 180
CELL_H = 180

# Пути к файлам
XML_PATH = "sprites.xml"
JSON_PATH = "sprites.json"
ASSETS_DIR = os.path.join("assets", "images")

# Регулярное выражение для парсинга координат (например, R1:C0, R0, C3)
COORD_RE = re.compile(r'^(?:R(?P<row>\d+))?:?(?:C(?P<col>\d+))?$')

def parse_coord(coord_str, default_row=None, default_col=None):
    if not coord_str:
        return None, None
    
    coord_str = coord_str.strip()
    match = COORD_RE.match(coord_str)
    if not match:
        raise ValueError(f"Некорректный формат координаты: '{coord_str}'. Должно быть вроде 'R1:C0', 'R0' или 'C3'")
    
    row_str = match.group('row')
    col_str = match.group('col')
    
    row = int(row_str) if row_str is not None else default_row
    col = int(col_str) if col_str is not None else default_col
    
    if row is None and col is None:
        raise ValueError(f"Координата '{coord_str}' должна содержать как минимум строку (R) или колонку (C)")
        
    return row, col

def validate_and_convert():
    print(f"[*] Начало валидации и конвертации '{XML_PATH}'...")
    
    # 1. Проверка существования XML-файла
    if not os.path.exists(XML_PATH):
        print(f"[Ошибка] Файл '{XML_PATH}' не найден.")
        sys.exit(1)
        
    # 2. Валидация синтаксиса XML
    try:
        tree = ET.parse(XML_PATH)
        root = tree.getroot()
    except ET.ParseError as e:
        print(f"[Ошибка] Ошибка синтаксиса XML в файле '{XML_PATH}':")
        print(f"  Строка: {e.position[0]}, Колонка: {e.position[1]}")
        print(f"  Детали: {e}")
        sys.exit(1)
        
    # 3. Валидация структуры XML-дерева
    if root.tag != "sprites":
        print(f"[Ошибка] Корневой тег должен быть <sprites>, найдено: <{root.tag}>")
        sys.exit(1)
        
    result_data = {}
    
    for group in root:
        if group.tag != "group":
            print(f"[Ошибка] Внутри <sprites> разрешены только теги <group>, найдено: <{group.tag}>")
            sys.exit(1)
            
        object_name = group.attrib.get("object")
        if not object_name:
            print(f"[Ошибка] Тег <group> должен иметь атрибут 'object' (например, <group object=\"player\">)")
            sys.exit(1)
            
        result_data[object_name] = {}
        
        for s_set in group:
            if s_set.tag != "set":
                print(f"[Ошибка] Внутри <group> разрешены только теги <set>, найдено: <{s_set.tag}>")
                sys.exit(1)
                
            action_name = s_set.attrib.get("action")
            if not action_name:
                print(f"[Ошибка] Тег <set> в группе '{object_name}' должен иметь атрибут 'action' (например, <set action=\"idle\">)")
                sys.exit(1)
                
            # Инициализация структуры для экшена
            action_data = {
                "file": None,
                "fps": None,
                "frames": []
            }
            
            # Читаем содержимое <set>
            file_name = None
            fps_val = None
            
            for child in s_set:
                if child.tag == "file":
                    file_name = (child.text or "").strip()
                    if not file_name:
                        print(f"[Ошибка] Тег <file> в экшене '{action_name}' группы '{object_name}' пуст")
                        sys.exit(1)
                    # Проверяем физическое наличие png-файла в папке ассетов
                    asset_path = os.path.join(ASSETS_DIR, file_name)
                    if not os.path.exists(asset_path):
                        print(f"[Предупреждение] Текстура '{file_name}' не найдена по пути '{asset_path}'")
                        
                    action_data["file"] = file_name
                    
                elif child.tag == "fps":
                    try:
                        fps_val = float((child.text or "").strip())
                        action_data["fps"] = fps_val
                    except ValueError:
                        print(f"[Ошибка] Значение <fps> в экшене '{action_name}' группы '{object_name}' должно быть числом")
                        sys.exit(1)
                        
                elif child.tag == "frame":
                    # Парсим структуру кадра
                    center_elem = child.find("center")
                    if center_elem is None:
                        print(f"[Ошибка] Каждый <frame> в экшене '{action_name}' группы '{object_name}' обязан содержать тег <center>")
                        sys.exit(1)
                        
                    center_text = (center_elem.text or "").strip()
                    try:
                        c_row, c_col = parse_coord(center_text)
                        if c_row is None or c_col is None:
                            print(f"[Ошибка] Тег <center> ('{center_text}') должен содержать и строку, и колонку (например, 'R1:C0')")
                            sys.exit(1)
                    except ValueError as e:
                        print(f"[Ошибка] Ошибка парсинга <center> в экшене '{action_name}' группы '{object_name}': {e}")
                        sys.exit(1)
                        
                    # Собираем все задействованные ячейки для этого кадра
                    cells = [(c_row, c_col)]
                    
                    # Проверяем дополнительные теги смещений
                    for sub in child:
                        if sub.tag == "center":
                            continue
                        elif sub.tag in ("top", "left", "right"):
                            sub_text = (sub.text or "").strip()
                            try:
                                # Если строка или колонка опущены, берем их из center
                                r, c = parse_coord(sub_text, default_row=c_row, default_col=c_col)
                                cells.append((r, c))
                            except ValueError as e:
                                print(f"[Ошибка] Ошибка парсинга <{sub.tag}> ('{sub_text}') в экшене '{action_name}' группы '{object_name}': {e}")
                                sys.exit(1)
                        else:
                            print(f"[Ошибка] Неизвестный тег <{sub.tag}> внутри <frame> в экшене '{action_name}' группы '{object_name}'")
                            sys.exit(1)
                            
                    # Вычисляем объединяющий Bounding Box в пикселях
                    min_row = min(r for r, c in cells)
                    max_row = max(r for r, c in cells)
                    min_col = min(c for r, c in cells)
                    max_col = max(c for r, c in cells)
                    
                    x = min_col * CELL_W
                    y = min_row * CELL_H
                    w = (max_col - min_col + 1) * CELL_W
                    h = (max_row - min_row + 1) * CELL_H
                    
                    # Записываем регион кадра [x, y, width, height]
                    action_data["frames"].append([x, y, w, h])
                else:
                    print(f"[Ошибка] Неизвестный тег <{child.tag}> внутри <set> в экшене '{action_name}' группы '{object_name}'")
                    sys.exit(1)
                    
            if not action_data["file"]:
                print(f"[Ошибка] Экшен '{action_name}' группы '{object_name}' не содержит обязательного тега <file>")
                sys.exit(1)
                
            if not action_data["frames"]:
                print(f"[Ошибка] Экшен '{action_name}' группы '{object_name}' не содержит кадров <frame>")
                sys.exit(1)
                
            result_data[object_name][action_name] = action_data
            
    # Записываем отвалидированные и конвертированные данные в красивый JSON
    try:
        with open(JSON_PATH, "w", encoding="utf-8") as f:
            json.dump(result_data, f, indent=4, ensure_ascii=False)
        print(f"[+] Успешно! Файл '{JSON_PATH}' обновлен и готов к использованию в Godot.")
    except IOError as e:
        print(f"[Ошибка] Не удалось записать файл '{JSON_PATH}': {e}")
        sys.exit(1)

if __name__ == "__main__":
    validate_and_convert()
