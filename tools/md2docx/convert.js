const fs = require('fs');
const path = require('path');
const { marked } = require('marked');
const {
  Document,
  Packer,
  Paragraph,
  TextRun,
  HeadingLevel,
  Table,
  TableRow,
  TableCell,
  WidthType,
  BorderStyle,
  ShadingType,
  AlignmentType,
} = require('docx');

const ROOT = path.resolve(__dirname, '..', '..');
const OUT_DIR = path.join(ROOT, 'docs_docx');

const FILES = [
  'PHAN_BIEN_HOI_DONG_CNTT_CHUYEN_SAU.md',
  'LOGIC_LUONG_VA_THUAT_TOAN_BAO_VE.md',
  'QA_VAN_DAP.md',
];

const border = { style: BorderStyle.SINGLE, size: 4, color: 'CCCCCC' };
const borders = { top: border, bottom: border, left: border, right: border };

function inlineRuns(tokens, base = {}) {
  const runs = [];
  if (!tokens) return runs;
  for (const t of tokens) {
    if (t.type === 'text') {
      runs.push(new TextRun({ text: t.text, ...base, font: 'Times New Roman', size: base.size || 22 }));
    } else if (t.type === 'strong') {
      runs.push(...inlineRuns(t.tokens || [{ type: 'text', text: t.text }], { ...base, bold: true }));
    } else if (t.type === 'em') {
      runs.push(...inlineRuns(t.tokens || [{ type: 'text', text: t.text }], { ...base, italics: true }));
    } else if (t.type === 'codespan') {
      runs.push(
        new TextRun({
          text: t.text,
          font: 'Consolas',
          size: 18,
          bold: base.bold,
          color: '8338A0',
        }),
      );
    } else if (t.type === 'link') {
      runs.push(
        new TextRun({
          text: t.text || t.href,
          font: 'Times New Roman',
          size: base.size || 22,
          color: '0563C1',
          underline: {},
        }),
      );
    } else if (t.type === 'escape' || t.type === 'html') {
      runs.push(new TextRun({ text: t.text || '', font: 'Times New Roman', size: base.size || 22, ...base }));
    } else if (t.tokens) {
      runs.push(...inlineRuns(t.tokens, base));
    } else if (t.text) {
      runs.push(new TextRun({ text: t.text, font: 'Times New Roman', size: base.size || 22, ...base }));
    }
  }
  return runs;
}

function cellParagraphs(text, opts = {}) {
  const lines = String(text ?? '').split(/\n/);
  return lines.map(
    (line) =>
      new Paragraph({
        children: [
          new TextRun({
            text: line.replace(/<[^>]+>/g, '').replace(/\*\*/g, '').replace(/`/g, ''),
            font: 'Times New Roman',
            size: opts.header ? 20 : 18,
            bold: !!opts.header,
          }),
        ],
      }),
  );
}

function tableFromToken(token) {
  const rows = [];
  const headers = token.header || [];
  if (headers.length) {
    rows.push(
      new TableRow({
        children: headers.map(
          (h) =>
            new TableCell({
              borders,
              width: { size: Math.floor(9000 / Math.max(headers.length, 1)), type: WidthType.DXA },
              shading: { type: ShadingType.CLEAR, fill: 'E8EEF7' },
              children: cellParagraphs(h.text, { header: true }),
            }),
        ),
      }),
    );
  }
  for (const row of token.rows || []) {
    rows.push(
      new TableRow({
        children: row.map(
          (c) =>
            new TableCell({
              borders,
              width: { size: Math.floor(9000 / Math.max(row.length, 1)), type: WidthType.DXA },
              children: cellParagraphs(c.text),
            }),
        ),
      }),
    );
  }
  return new Table({ width: { size: 9000, type: WidthType.DXA }, rows });
}

function headingLevel(depth) {
  if (depth <= 1) return HeadingLevel.HEADING_1;
  if (depth === 2) return HeadingLevel.HEADING_2;
  if (depth === 3) return HeadingLevel.HEADING_3;
  return HeadingLevel.HEADING_4;
}

function tokensToBlocks(tokens) {
  const blocks = [];
  for (const token of tokens) {
    switch (token.type) {
      case 'heading': {
        blocks.push(
          new Paragraph({
            heading: headingLevel(token.depth),
            spacing: { before: 240, after: 120 },
            children: inlineRuns(token.tokens, {
              bold: true,
              size: token.depth === 1 ? 32 : token.depth === 2 ? 28 : 24,
            }),
          }),
        );
        break;
      }
      case 'paragraph': {
        blocks.push(
          new Paragraph({
            spacing: { after: 120, line: 276 },
            children: inlineRuns(token.tokens, { size: 22 }),
          }),
        );
        break;
      }
      case 'blockquote': {
        for (const inner of token.tokens || []) {
          if (inner.type === 'paragraph') {
            blocks.push(
              new Paragraph({
                spacing: { after: 100 },
                indent: { left: 360 },
                border: { left: { style: BorderStyle.SINGLE, size: 24, color: '2F6FED', space: 8 } },
                children: inlineRuns(inner.tokens, { size: 21, italics: true, color: '333333' }),
              }),
            );
          } else {
            blocks.push(...tokensToBlocks([inner]));
          }
        }
        break;
      }
      case 'list': {
        let i = 0;
        for (const item of token.items || []) {
          i += 1;
          const prefix = token.ordered ? `${i}. ` : '• ';
          const first = (item.tokens || []).find((t) => t.type === 'paragraph');
          const runs = [
            new TextRun({ text: prefix, font: 'Times New Roman', size: 22 }),
            ...inlineRuns(first ? first.tokens : [{ type: 'text', text: item.text || '' }], { size: 22 }),
          ];
          blocks.push(
            new Paragraph({
              spacing: { after: 80 },
              indent: { left: 360 },
              children: runs,
            }),
          );
          const nested = (item.tokens || []).filter((t) => t.type === 'list');
          if (nested.length) blocks.push(...tokensToBlocks(nested));
        }
        break;
      }
      case 'code': {
        const lines = (token.text || '').replace(/\r\n/g, '\n').split('\n');
        for (const line of lines) {
          blocks.push(
            new Paragraph({
              spacing: { after: 0 },
              shading: { type: ShadingType.CLEAR, fill: 'F5F5F5' },
              children: [
                new TextRun({
                  text: line.length ? line : ' ',
                  font: 'Consolas',
                  size: 16,
                }),
              ],
            }),
          );
        }
        blocks.push(new Paragraph({ children: [] }));
        break;
      }
      case 'table': {
        blocks.push(tableFromToken(token));
        blocks.push(new Paragraph({ children: [] }));
        break;
      }
      case 'hr': {
        blocks.push(
          new Paragraph({
            spacing: { before: 120, after: 120 },
            border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: '999999', space: 1 } },
            children: [],
          }),
        );
        break;
      }
      case 'space':
        break;
      default: {
        if (token.tokens) blocks.push(...tokensToBlocks(token.tokens));
        else if (token.text) {
          blocks.push(
            new Paragraph({
              children: [new TextRun({ text: token.text, font: 'Times New Roman', size: 22 })],
            }),
          );
        }
      }
    }
  }
  return blocks;
}

async function convertOne(fileName) {
  const mdPath = path.join(ROOT, fileName);
  const md = fs.readFileSync(mdPath, 'utf8');
  const tokens = marked.lexer(md);
  const children = [
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { after: 200 },
      children: [
        new TextRun({
          text: fileName.replace(/\.md$/i, ''),
          bold: true,
          font: 'Times New Roman',
          size: 36,
        }),
      ],
    }),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { after: 400 },
      children: [
        new TextRun({
          text: 'SafeMarket — Tài liệu ôn bảo vệ / phản biện (xuất từ Markdown)',
          italics: true,
          font: 'Times New Roman',
          size: 20,
          color: '666666',
        }),
      ],
    }),
    ...tokensToBlocks(tokens),
  ];

  const doc = new Document({
    styles: {
      default: {
        document: {
          styles: [{ id: 'Normal', run: { font: 'Times New Roman', size: 22 } }],
        },
      },
    },
    sections: [
      {
        properties: {
          page: {
            margin: { top: 720, bottom: 720, left: 720, right: 720 },
          },
        },
        children,
      },
    ],
  });

  const outName = fileName.replace(/\.md$/i, '.docx');
  const outPath = path.join(OUT_DIR, outName);
  const buf = await Packer.toBuffer(doc);
  fs.writeFileSync(outPath, buf);
  return outPath;
}

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  for (const f of FILES) {
    const out = await convertOne(f);
    console.log('OK', out);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
