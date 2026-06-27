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

def parse_coord(coord_str, default_row=None, default_col=None):
    if not coord_str:
        return None, None
    
    coord_str = coord_str.strip()
    
    # Разделяем по двоеточию, если оно есть
    if ":" in coord_str:
        parts = coord_str.split(":")
        if len(parts) != 2:
            raise ValueError(f"Некорректный формат координаты: '{coord_str}'. Должно быть ровно два элемента, разделенных двоеточием.")
        row_part, col_part = parts[0].strip(), parts[1].strip()
    else:
        # Если двоеточия нет, это может быть R5, C3, Rsame, Cnext и т.д.
        row_part, col_part = None, None
        if coord_str.startswith("R"):
            row_part = coord_str
        elif coord_str.startswith("C"):
            col_part = coord_str
        else:
            raise ValueError(f"Некорректный формат координаты: '{coord_str}'. Должен начинаться с R или C, либо содержать двоеточие.")

    def resolve_part(part, last_val, prefix):
        if part is None:
            return last_val
            
        # Удаляем префикс, если он есть
        if part.startswith(prefix):
            part = part[len(prefix):]
            
        if part == "same":
            if last_val is None:
                raise ValueError(f"Невозможно использовать 'same' для {prefix} без предыдущего значения")
            return last_val
        elif part == "next":
            if last_val is None:
                raise ValueError(f"Невозможно использовать 'next' для {prefix} без предыдущего значения")
            return last_val + 1
        elif part == "prev":
            if last_val is None:
                raise ValueError(f"Невозможно использовать 'prev' для {prefix} без предыдущего значения")
            return last_val - 1
        else:
            try:
                return int(part)
            except ValueError:
                raise ValueError(f"Неверный формат числового значения '{part}' для {prefix}")

    row = resolve_part(row_part, default_row, "R")
    col = resolve_part(col_part, default_col, "C")
    
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
                "spf": None,
                "frames": []
            }
            last_row = None
            last_col = None
            
            # Читаем содержимое <set>
            file_name = None
            fps_val = None
            spf_val = None
            
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
                    except ValueError:
                        print(f"[Ошибка] Значение <fps> в экшене '{action_name}' группы '{object_name}' должно быть числом")
                        sys.exit(1)
                        
                elif child.tag == "spf":
                    try:
                        spf_val = float((child.text or "").strip())
                    except ValueError:
                        print(f"[Ошибка] Значение <spf> в экшене '{action_name}' группы '{object_name}' должно быть числом")
                        sys.exit(1)
                        
                elif child.tag == "frame":
                    # Парсим структуру кадра
                    from_elem = child.find("from")
                    if from_elem is None:
                        print(f"[Ошибка] Каждый <frame> в экшене '{action_name}' группы '{object_name}' обязан содержать тег <from>")
                        sys.exit(1)
                        
                    from_text = from_elem.attrib.get("tile", "").strip()
                    if not from_text:
                        print(f"[Ошибка] Тег <from> в экшене '{action_name}' группы '{object_name}' обязан иметь заполненный атрибут 'tile' (например, <from tile=\"R1:C0\" />)")
                        sys.exit(1)
                        
                    # Определяем количество повторений (по умолчанию 1)
                    repeat_count = 1
                    for sub in child:
                        if "repeat" in sub.attrib:
                            try:
                                repeat_count = max(repeat_count, int(sub.attrib["repeat"]))
                            except ValueError:
                                print(f"[Ошибка] Значение 'repeat' должно быть целым числом в экшене '{action_name}' группы '{object_name}'")
                                sys.exit(1)
                                
                    # Смещения по умолчанию
                    top_offset = 0
                    bottom_offset = 0
                    left_offset = 0
                    right_offset = 0
                    
                    # Проверяем дочерние теги внутри <frame>
                    for sub in child:
                        if sub.tag == "from":
                            continue
                        elif sub.tag == "extend":
                            # Парсим атрибуты смещения
                            for attr, val in sub.attrib.items():
                                if attr not in ("top", "bottom", "left", "right", "repeat"):
                                    print(f"[Ошибка] Неизвестный атрибут '{attr}' в теге <extend> в экшене '{action_name}' группы '{object_name}'")
                                    sys.exit(1)
                                try:
                                    if attr == "repeat":
                                        continue
                                    int_val = int(val)
                                    if int_val < 0:
                                        print(f"[Ошибка] Значение атрибута '{attr}' в <extend> в экшене '{action_name}' группы '{object_name}' должно быть положительным (найдено: {val})")
                                        sys.exit(1)
                                    
                                    if attr == "top":
                                        top_offset = int_val
                                    elif attr == "bottom":
                                        bottom_offset = int_val
                                    elif attr == "left":
                                        left_offset = int_val
                                    elif attr == "right":
                                        right_offset = int_val
                                except ValueError:
                                    print(f"[Ошибка] Значение атрибута '{attr}' в <extend> в экшене '{action_name}' группы '{object_name}' должно быть целым числом (найдено: '{val}')")
                                    sys.exit(1)
                        else:
                            print(f"[Ошибка] Неизвестный тег <{sub.tag}> внутри <frame> в экшене '{action_name}' группы '{object_name}'")
                            sys.exit(1)
                            
                    for _ in range(repeat_count):
                        try:
                            c_row, c_col = parse_coord(from_text, last_row, last_col)
                            if c_row is None or c_col is None:
                                print(f"[Ошибка] Атрибут 'tile' ('{from_text}') тега <from> должен содержать и строку, и колонку (например, 'R1:C0')")
                                sys.exit(1)
                        except ValueError as e:
                            print(f"[Ошибка] Ошибка парсинга атрибута 'tile' в <from> в экшене '{action_name}' группы '{object_name}': {e}")
                            sys.exit(1)
                            
                        # Обновляем последние координаты
                        last_row = c_row
                        last_col = c_col
                        
                        # Вычисляем объединяющий Bounding Box в пикселях
                        min_row = c_row - top_offset
                        max_row = c_row + bottom_offset
                        min_col = c_col - left_offset
                        max_col = c_col + right_offset
                        
                        x = min_col * CELL_W
                        y = min_row * CELL_H
                        w = (max_col - min_col + 1) * CELL_W
                        h = (max_row - min_row + 1) * CELL_H
                        
                        # Записываем регион кадра [x, y, width, height]
                        action_data["frames"].append([x, y, w, h])
                else:
                    print(f"[Ошибка] Неизвестный тег <{child.tag}> внутри <set> в экшене '{action_name}' группы '{object_name}'")
                    sys.exit(1)
                    
            # Валидация fps и spf
            if fps_val is not None and spf_val is not None:
                print(f"[Ошибка] В экшене '{action_name}' группы '{object_name}' указаны одновременно и <fps>, и <spf>. Разрешено указывать только что-то одно.")
                sys.exit(1)
                
            final_spf = None
            if spf_val is not None:
                final_spf = round(spf_val, 2)
            elif fps_val is not None:
                if fps_val <= 0:
                    print(f"[Ошибка] Значение <fps> в экшене '{action_name}' группы '{object_name}' должно быть строго больше 0")
                    sys.exit(1)
                final_spf = round(1.0 / fps_val, 2)
                
            action_data["spf"] = final_spf
            
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
