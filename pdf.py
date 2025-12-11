import os
import sys
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

def gather_files(root_dir, extensions=None):
    """
    Retorna uma lista de caminhos absolutos para arquivos dentro de root_dir,
    filtrando por extensões (lista de strings '.py', '.dart', etc.). Se extensions for None, pega todos os arquivos.
    """
    file_paths = []
    for dirpath, dirnames, filenames in os.walk(root_dir):
        for fname in filenames:
            if extensions is None or any(fname.endswith(ext) for ext in extensions):
                file_paths.append(os.path.join(dirpath, fname))
    return file_paths

def write_file_to_pdf(c, file_path, indent=0, max_chars_per_line=100):
    """
    Escreve um cabeçalho (caminho) e o conteúdo do arquivo no PDF canvas c.
    Quebra linhas longas para não ultrapassar a largura da página.
    """
    c.drawString(40 + indent*10, c._curr_y, f"Arquivo: {file_path}")
    c._curr_y -= 14
    c.drawString(40 + indent*10, c._curr_y, "-"*80)
    c._curr_y -= 14

    try:
        with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
            for line in f:
                # opcional: limitar comprimento
                while len(line) > max_chars_per_line:
                    chunk, line = line[:max_chars_per_line], line[max_chars_per_line:]
                    c.drawString(40 + indent*10, c._curr_y, chunk.rstrip())
                    c._curr_y -= 12
                    if c._curr_y < 50:
                        c.showPage()
                        c._curr_y = A4[1] - 50
                c.drawString(40 + indent*10, c._curr_y, line.rstrip())
                c._curr_y -= 12
                if c._curr_y < 50:
                    c.showPage()
                    c._curr_y = A4[1] - 50
    except Exception as e:
        c.drawString(40 + indent*10, c._curr_y, f"[Não foi possível ler o arquivo: {e}]")
        c._curr_y -= 14

    c._curr_y -= 20  # espaço entre arquivos

def create_project_pdf(root_dir, output_pdf, extensions=None):
    c = canvas.Canvas(output_pdf, pagesize=A4)
    # cria um atributo para controlar y
    c._curr_y = A4[1] - 50

    file_paths = gather_files(root_dir, extensions=extensions)
    file_paths.sort()

    for path in file_paths:
        write_file_to_pdf(c, path)

    c.save()
    print(f"PDF gerado com sucesso: {output_pdf}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Uso: python gerar_pdf_projeto.py <diretório_projeto> <saida.pdf> [extensão1 extensão2 ...]")
        sys.exit(1)

    root = sys.argv[1]
    output = sys.argv[2]
    exts = sys.argv[3:] if len(sys.argv) > 3 else None

    create_project_pdf(root, output, extensions=exts)
