from docx import Document
from fpdf import FPDF

def convert_docx_to_pdf(docx_path: str, pdf_path: str):
    # Load the DOCX file
    doc = Document(docx_path)
    
    # Create a PDF object
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Arial", size=12)
    
    # Add each paragraph in the DOCX file to the PDF
    for para in doc.paragraphs:
        pdf.multi_cell(0, 10, para.text)
    
    # Save the PDF
    pdf.output(pdf_path)
