const fs = require('fs');
const path = require('path');
const {
  Document,
  Packer,
  Paragraph,
  TextRun,
  Table,
  TableRow,
  TableCell,
  Header,
  Footer,
  PageNumber,
  AlignmentType,
  HeadingLevel,
  BorderStyle,
  WidthType,
  ShadingType,
  VerticalAlign,
  PageBreak,
} = require('docx');

const FONT = 'Times New Roman';
const PURPLE = '5B2C6F';
const MUTED = '555555';
const SPEAK_BG = 'F3EEF7';
const NOTE_BG = 'F7F7F7';
const HEADER_BG = '3D1F4E';
const ACCENT_BG = 'EDE4F3';

const thin = { style: BorderStyle.SINGLE, size: 4, color: 'CCCCCC' };
const borders = { top: thin, bottom: thin, left: thin, right: thin };
const noBorder = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };
const noBorders = { top: noBorder, bottom: noBorder, left: noBorder, right: noBorder };

function run(text, opts = {}) {
  return new TextRun({
    text,
    font: FONT,
    size: opts.size || 22,
    bold: !!opts.bold,
    italics: !!opts.italics,
    color: opts.color || '1A1A1A',
    underline: opts.underline ? {} : undefined,
  });
}

function p(children, opts = {}) {
  return new Paragraph({
    spacing: { after: opts.after ?? 120, before: opts.before ?? 0, line: opts.line || 276 },
    alignment: opts.align,
    shading: opts.fill ? { type: ShadingType.CLEAR, fill: opts.fill } : undefined,
    indent: opts.indent ? { left: opts.indent } : undefined,
    keepLines: opts.keepLines,
    children: Array.isArray(children) ? children : [run(children, opts)],
  });
}

function heading(text, level = HeadingLevel.HEADING_1) {
  return new Paragraph({
    heading: level,
    spacing: { before: level === HeadingLevel.HEADING_1 ? 280 : 200, after: 120 },
    children: [run(text, { bold: true, size: level === HeadingLevel.HEADING_1 ? 32 : 26, color: PURPLE })],
  });
}

function labelLine(label, text) {
  return p([run(label + '  ', { bold: true, size: 22, color: PURPLE }), run(text, { size: 22 })], { after: 80 });
}

function speakBlock(lines) {
  const paras = [
    p([run('NÓI  —  đọc gần như nguyên văn', { bold: true, size: 20, color: PURPLE })], {
      fill: SPEAK_BG,
      after: 40,
      before: 80,
    }),
  ];
  for (const line of lines) {
    paras.push(
      p([run(line, { size: 24 })], {
        fill: SPEAK_BG,
        after: 80,
        indent: 160,
        line: 312,
      }),
    );
  }
  return paras;
}

function noteBlock(title, lines) {
  const paras = [
    p([run(title, { bold: true, size: 20, color: MUTED, italics: true })], {
      fill: NOTE_BG,
      after: 40,
      before: 60,
    }),
  ];
  for (const line of lines) {
    paras.push(p([run(line, { size: 21, italics: true, color: MUTED })], { fill: NOTE_BG, after: 60, indent: 160 }));
  }
  return paras;
}

function cell(text, opts = {}) {
  const fill = opts.fill || (opts.header ? HEADER_BG : undefined);
  const color = opts.header ? 'FFFFFF' : opts.color || '1A1A1A';
  return new TableCell({
    borders,
    width: { size: opts.width || 2000, type: WidthType.DXA },
    shading: fill ? { type: ShadingType.CLEAR, fill } : undefined,
    verticalAlign: VerticalAlign.CENTER,
    margins: { top: 60, bottom: 60, left: 80, right: 80 },
    children: [
      new Paragraph({
        alignment: opts.align || AlignmentType.LEFT,
        children: [run(String(text), { bold: !!opts.header || !!opts.bold, size: opts.size || 20, color })],
      }),
    ],
  });
}

function makeTable(headers, rows, widths) {
  return new Table({
    width: { size: 10080, type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({
        tableHeader: true,
        children: headers.map((h, i) => cell(h, { header: true, width: widths[i], align: AlignmentType.CENTER })),
      }),
      ...rows.map(
        (r, ri) =>
          new TableRow({
            children: r.map((c, i) =>
              cell(c.text, {
                width: widths[i],
                bold: c.bold,
                fill: c.fill || (ri % 2 === 1 ? ACCENT_BG : undefined),
                align: c.align,
                color: c.color,
              }),
            ),
          }),
      ),
    ],
  });
}

const slides = [
  {
    no: 1,
    title: 'Trang bìa — chào Hội đồng',
    timeFull: '25–30 giây',
    timeShort: '20 giây',
    look: 'Đứng thẳng, nhìn Hội đồng, mỉm cười ngắn. Không đọc hết dòng công nghệ trên slide.',
    say: [
      'Kính thưa quý Thầy Cô trong Hội đồng bảo vệ.',
      'Nhóm em gồm Trương Trí Hiền và Nguyễn Tấn Lộc, xin được trình bày khóa luận tốt nghiệp: “Xây dựng ứng dụng sàn giao dịch trung gian SafeMarket tích hợp định danh điện tử eKYC”.',
      'Hệ thống được hiện thực trên Flutter và NestJS, dùng SQL Server làm nguồn sự thật cho tiền và danh tính, Firebase cho chat realtime, VNPay sandbox cho thanh toán ký quỹ, và FPT.AI cho OCR căn cước.',
    ],
    how: [
      'Giọng chậm, rõ, hơi trang trọng. Nghỉ một nhịp sau tên đề tài.',
      'Không đọc danh sách công nghệ như đang điểm danh. Chỉ nêu vai trò từng thành phần — Hội đồng sẽ thấy logo trên slide.',
      'Nếu hồi hộp: thở ra nhẹ trước câu đầu, hai tay để tự nhiên, không đút túi.',
    ],
    cut: 'Giữ câu chào và tên đề tài. Bỏ câu liệt kê công nghệ.',
  },
  {
    no: 2,
    title: 'Nội dung trình bày',
    timeFull: '15–20 giây',
    timeShort: 'Bỏ slide này nếu chỉ có 5–6 phút',
    look: 'Chỉ tay theo bảy mục, không đọc từng dòng. Nói “ba trụ cột” rõ hơn các mục còn lại.',
    say: [
      'Em xin trình bày trong khoảng tám đến mười phút, theo bảy nhóm: bài toán, mục tiêu, so sánh với nền tảng hiện có, kiến trúc, ba trụ cột eKYC – escrow – điểm tín nhiệm, rồi cơ sở dữ liệu, kết quả và hạn chế.',
      'Phần trọng tâm em sẽ dành cho ba trụ cột, vì đó là cách SafeMarket xử lý rủi ro của chợ đồ cũ.',
    ],
    how: [
      'Đây là slide “bản đồ”, không phải slide nội dung. Nói nhanh, chuyển ngay.',
      'Nhấn cụm “ba trụ cột” — câu này neo toàn bộ bài nói.',
    ],
    cut: 'Bỏ hẳn. Sau slide 1 nhảy thẳng sang bài toán.',
  },
  {
    no: 3,
    title: 'Bài toán — ba lỗ hổng chợ C2C đồ cũ',
    timeFull: '50–60 giây',
    timeShort: '40 giây',
    look: 'Chỉ lần lượt 01, 02, 03. Dừng một nhịp ở dòng kết “eKYC + điểm + escrow”.',
    say: [
      'Lý do nhóm chọn đề tài xuất phát từ ba lỗ hổng thực tế của chợ C2C đồ cũ tại Việt Nam.',
      'Thứ nhất, danh tính yếu. Người dùng đăng ký bằng OTP hoặc SIM rác. Tài khoản ảo bị khóa xong tạo lại rất dễ. Nền tảng không gắn được người thật với giao dịch.',
      'Thứ hai, tín nhiệm dễ làm giả. Thang năm sao bị thao túng bằng đơn ảo, nên người mua không biết đối phương đáng tin đến mức nào.',
      'Thứ ba, tiền nằm ngoài hệ thống. Hai bên chuyển khoản tay. Khi không nhận hàng, nền tảng không giữ tiền nên không hoàn được một cách có kiểm soát.',
      'SafeMarket giải ba lỗ hổng đó bằng ba lớp: định danh eKYC, điểm tín nhiệm theo hành vi thật, và giữ tiền ký quỹ — escrow.',
    ],
    how: [
      'Đây là slide “vì sao làm”. Nói chậm hơn slide mục lục. Mỗi “Thứ nhất / hai / ba” là một hơi thở.',
      'Đừng kể chuyện dài về lừa đảo. Hội đồng cần thấy nhóm nắm đúng bài toán kỹ thuật, không phải phóng sự.',
      'Câu cuối phải dứt khoát: ba lớp giải pháp = ba trụ cột sẽ triển khai ngay sau đó.',
    ],
    cut: 'Nói mỗi lỗ hổng một câu, rồi kết bằng câu SafeMarket.',
  },
  {
    no: 4,
    title: 'Mục tiêu và phạm vi',
    timeFull: '35–45 giây',
    timeShort: '25 giây',
    look: 'Nhìn cột trái khi nói mục tiêu, cột phải khi nói giới hạn. Nhấn dòng “không làm AI recommendation”.',
    say: [
      'Về mục tiêu, nhóm làm những gì có thật trong code. Một, định danh bằng eKYC — OCR căn cước và liveness — trước khi được mua hoặc bán. Hai, xây chợ đồ cũ: đăng tin, tìm kiếm, chat, đặt hàng. Ba, thanh toán ký quỹ qua VNPay, giải ngân vào ví người bán khi đơn hoàn tất. Bốn, điểm tín nhiệm từ 0 đến 1000, hạng Bronze đến Diamond theo sự kiện thật. Năm, Admin duyệt eKYC, ẩn tin, xử lý báo cáo và tranh chấp.',
      'Về phạm vi, client chính là Android Flutter; backend NestJS và SQL Server. VNPay chạy sandbox. Nhóm chưa kết nối đơn vị vận chuyển thật, thông báo mới trong app — chưa FCM, yêu thích lưu máy chưa đồng bộ.',
      'Nhóm cố ý không làm gợi ý sản phẩm kiểu AI hay collaborative filtering. Thuật toán của đồ án nằm ở điểm tín nhiệm, khóa hàng chống bán trùng, chữ ký VNPay và phiên eKYC — không phải mô hình học máy.',
    ],
    how: [
      'Câu “làm được gì / cố ý không làm gì” rất quan trọng khi phản biện. Nói rành, đừng nuốt chữ.',
      'Nếu Hội đồng hay hỏi “sao không làm AI?” thì câu cuối slide này đã trả lời sẵn — nhắc lại khi vấn đáp.',
    ],
    cut: 'Ba câu: eKYC + chợ + escrow; điểm + Admin; phạm vi Android/sandbox và không làm recommendation.',
  },
  {
    no: 5,
    title: 'So sánh với nền tảng khảo sát (Chợ Tốt)',
    timeFull: '35–40 giây',
    timeShort: '20 giây',
    look: 'Chỉ cột “SafeMarket”, không đọc hết bảng. Đi 3 hàng: định danh, thanh toán, tranh chấp.',
    say: [
      'Nhóm khảo sát Chợ Tốt như nền tảng đại diện. SafeMarket kế thừa trải nghiệm mua bán đồ cũ, nhưng thay tầng xác thực yếu.',
      'Chợ Tốt dùng OTP hoặc mạng xã hội; SafeMarket bắt buộc eKYC. Họ dùng thang năm sao; nhóm dùng điểm 0 đến 1000 cộng theo sự kiện. Thanh toán của họ thỏa thuận ngoài app; nhóm giữ tiền escrow và chỉ giải ngân khi nhận hàng. Chưa Verified thì không đăng tin, không mua. Tranh chấp được Admin xử trên đơn đang Holding, chứ không chỉ hỗ trợ sau sự việc.',
    ],
    how: [
      'Giọng đối chiếu, không giọng “chê”. Nói “kế thừa trải nghiệm, thay tầng yếu” — đó là định vị đúng.',
      'Đừng khẳng định SafeMarket “tốt hơn Chợ Tốt về quy mô”. Chỉ nói khác ở lớp an toàn giao dịch.',
    ],
    cut: 'Một câu: kế thừa UX Chợ Tốt, thay OTP bằng eKYC, sao bằng điểm, chuyển khoản tay bằng escrow.',
  },
  {
    no: 6,
    title: 'Kiến trúc ba tầng',
    timeFull: '45–50 giây',
    timeShort: '35 giây',
    look: 'Chỉ từ trên xuống: Flutter → NestJS → SQL, rồi hệ thống ngoài bên phải.',
    say: [
      'Kiến trúc ba tầng. Client Flutter không nói chuyện thẳng với SQL. Mọi nghiệp vụ đi qua REST NestJS, có JWT, Guard và ValidationPipe.',
      'SQL Server, cơ sở SafeMarketDB, là nguồn sự thật cho người dùng, đơn hàng, tiền và điểm — chia năm schema Identity, Market, Finance, Reputation, Moderation.',
      'Bên ngoài: FPT.AI OCR căn cước, VNPay sandbox, Firebase Realtime Database cho chat và bình luận, SMTP gửi OTP.',
      'Nguyên tắc nhóm muốn nhấn: đơn hàng, tiền, điểm nằm ở SQL và NestJS. Firebase chỉ là kênh hội thoại realtime, không phải sổ cái tiền.',
    ],
    how: [
      'Câu “không nói chuyện thẳng với SQL” và “Firebase không phải sổ cái” hay được hỏi lại. Nói chậm, nhìn Hội đồng.',
      'Không đi sâu từng module ở slide này — module sẽ lộ ở slide chức năng.',
    ],
    cut: 'Flutter gọi Nest; SQL giữ tiền; Firebase chỉ chat. Xong.',
  },
  {
    no: 7,
    title: 'Công nghệ sử dụng',
    timeFull: '25–30 giây',
    timeShort: 'Bỏ nếu thiếu giờ',
    look: 'Quét 2–3 ô: Flutter, JWT, VNPay HMAC. Đừng đọc hết sáu ô.',
    say: [
      'Công nghệ được chọn theo bài toán, không chọn theo mốt.',
      'Flutter cho một codebase mobile, camera eKYC và liveness bằng ML Kit. NestJS chia module rõ: auth, ekyc, orders, payments. SQL có khóa ngoại, CHECK, trigger điểm, và synchronize tắt để không tự sửa schema.',
      'Access token mười lăm phút, refresh bảy ngày — token được hash SHA-256 và rotate khi dùng lại. VNPay ký URL bằng HMAC-SHA512, đối chiếu chữ ký IPN và return.',
    ],
    how: [
      'Nếu bị hỏi “sao dùng Firebase mà không WebSocket Nest?”: chat cần đẩy sự kiện; SQL giữ đơn và tiền — đã nói ở slide 6.',
      'Nếu bị hỏi synchronize false: để schema do script SQL kiểm soát, tránh TypeORM tự drop/alter.',
    ],
    cut: 'Bỏ slide. Chỉ nhắc JWT 15 phút và HMAC VNPay nếu Hội đồng hỏi.',
  },
  {
    no: 8,
    title: 'Trụ cột 1 — eKYC',
    timeFull: '65–75 giây',
    timeShort: '50 giây',
    look: 'Chỉ bốn bước trái sang phải. Nhấn dòng “API key nằm phía NestJS” và “Admin duyệt mới Verified”.',
    say: [
      'Trụ cột thứ nhất là eKYC — định danh trước khi mua bán. Client không gọi thẳng FPT.AI. Khóa API nằm phía NestJS.',
      'Bước một, chụp mặt trước căn cước, gọi scan-id-front, OCR lấy số căn cước, họ tên, ngày sinh. Bước hai, mặt sau: đặc điểm, ngày cấp, nơi cấp. Bước ba, liveness ngay trên máy bằng ML Kit: nhìn thẳng, quay trái, quay phải, cần ít nhất bốn điểm nhận dạng. Bước bốn, nộp hồ sơ, trạng thái Pending; chỉ khi Admin duyệt thành Verified thì tài khoản mới được mua và đăng tin.',
      'Máy trạng thái: Unverified, Pending, rồi Verified hoặc Rejected. Với face-match, ngưỡng similarity từ 0,72 từng dùng ở API cũ; giao diện hiện tại đi theo luồng Admin duyệt sau liveness.',
    ],
    how: [
      'Đây là slide kỹ thuật then chốt. Nói từng bước, đừng gộp thành “làm eKYC”.',
      'Nếu hỏi “OCR tự code không?”: không, tích hợp FPT.AI; app làm UX và liveness; server giữ session và khóa.',
      'Nếu hỏi face-match: nói thẳng UI hiện không gọi; ngưỡng 0,72 là của API cũ. Thành thật hơn là nói “có đủ face-match production”.',
      'Nhấn “chưa Verified thì không mua, không bán” — đây là cửa kiểm soát, không phải trang trí.',
    ],
    cut: 'Bốn bước + Admin duyệt + chưa Verified thì không giao dịch.',
  },
  {
    no: 9,
    title: 'Trụ cột 2 — Escrow và máy trạng thái đơn',
    timeFull: '65–75 giây',
    timeShort: '50 giây',
    look: 'Chạy ngón tay theo Pending → Paid → Shipped → Completed. Rồi chỉ ba ô dưới: chống trùng, giải ngân, tranh chấp.',
    say: [
      'Trụ cột thứ hai là escrow. Điểm then chốt: tiền không về tay người bán lúc đơn vừa Paid.',
      'Tạo đơn thì sản phẩm Reserved, trạng thái Pending. Khi VNPay gửi IPN thành công, đơn Paid, escrow Holding. Người bán đánh dấu đã gửi — Shipped. Người mua xác nhận nhận hàng kèm ảnh, đơn Completed: lúc đó mới Released và cộng tiền vào ví người bán.',
      'Chống bán trùng bằng ràng buộc UNIQUE trên product_id của Orders. Đơn bị hủy mới tái kích hoạt cùng món.',
      'Nếu tranh chấp, đơn Paid hoặc Shipped chuyển Disputed; Admin chọn hoàn cho người mua hoặc giải ngân cho người bán. Ví chỉ một cột số dư kiểu bigint đồng, không dùng số thực. Rút tiền thì trừ ngay trên ví, Admin duyệt rồi chuyển khoản ngoài hệ thống.',
    ],
    how: [
      'Câu mở “tiền không về tay người bán lúc Paid” phải nói chậm — đó là câu Hội đồng nhớ.',
      'Phân biệt rõ hai luồng: ONLINE_ESCROW mới Released và cộng ví; chuyển khoản ngân hàng chỉ đổi trạng thái.',
      'Nếu hỏi “tiền đang nằm đâu?”: buyer trả VNPay theo luồng hệ thống; Payment Holding; chưa vào STK seller.',
    ],
    cut: 'Paid = Holding; Completed + ảnh mới Released vào ví. UNIQUE chống bán trùng. Tranh chấp do Admin.',
  },
  {
    no: 10,
    title: 'Trụ cột 3 — Điểm tín nhiệm',
    timeFull: '50–60 giây',
    timeShort: '40 giây',
    look: 'Chỉ công thức trước, rồi bốn hạng, rồi vài mốc cộng trừ. Đừng đọc hết bảng điểm.',
    say: [
      'Trụ cột thứ ba là điểm tín nhiệm. Đây không phải mô hình machine learning, mà là cộng dồn sự kiện có kiểm soát.',
      'Điểm mới bằng min của 1000 và max của 0 với điểm cũ cộng delta. User mới khởi tạo 500, hạng Bronze.',
      'Hạng: Bronze dưới 300, Silver từ 300, Gold từ 600, Diamond từ 850. Ví dụ: hoàn tất đơn cộng 20 mỗi bên; nhận đánh giá năm sao cộng 30; bình luận cộng hoặc trừ 2; báo cáo mức high trừ 50; thua tranh chấp trừ 50.',
      'Khi chat, nếu đối phương dưới 300 điểm thì hệ thống cảnh báo. Mỗi lần ghi Point_Logs, trigger SQL cập nhật điểm, kẹp trong đoạn 0–1000, rồi gán lại hạng.',
    ],
    how: [
      'Khi bị hỏi “thuật toán của em là gì?”: trả lời đúng câu này, đừng vòng sang recommendation.',
      'Nêu trigger trg_UpdateScoreAndRank — cho thấy điểm không chỉ cộng ở application rồi quên kẹp trần.',
      'Không khoe “AI phát hiện gian lận”. Sentiment lexicon khoảng 46 cụm sẽ nói ở hạn chế.',
    ],
    cut: 'S’ = kẹp 0–1000 của S+Δ; start 500; hoàn tất +20; 5 sao +30; high report −50; trigger SQL.',
  },
  {
    no: 11,
    title: 'Cơ sở dữ liệu',
    timeFull: '30–35 giây',
    timeShort: '20 giây',
    look: 'Chỉ năm schema. Nhấn ba ràng buộc dưới slide, không đọc hết tên bảng.',
    say: [
      'Về dữ liệu: SQL giữ tiền và danh tính, Firebase giữ hội thoại.',
      'Năm schema tương ứng năm nhóm việc: Identity, Market, Finance, Reputation, Moderation.',
      'Ba ràng buộc nhóm muốn Hội đồng lưu ý. Một, product_id trên Orders là UNIQUE — một món chỉ một đơn đang hiệu lực. Hai, escrow_status gồm Holding, Released, Refunded. Ba, số dư ví kiểu bigint, có CHECK lớn hơn hoặc bằng 0, không dùng float để tránh sai tiền.',
    ],
    how: [
      'Nói “không dùng float” dứt khoát — đây là chi tiết kỹ thuật nhỏ nhưng thuyết phục.',
      'Nếu hỏi chat lưu SQL hay Firebase: realtime trên Firebase; SQL vẫn có bảng chat phục vụ đối soát, không phải kênh đẩy tin nhắn chính trên app.',
    ],
    cut: 'SQL tiền + danh tính; Firebase chat; UNIQUE; Holding/Released/Refunded; bigint.',
  },
  {
    no: 12,
    title: 'Chức năng đã hiện thực',
    timeFull: '20–25 giây',
    timeShort: 'Bỏ nếu thiếu giờ',
    look: 'Quét ba cột: người dùng, giao dịch, quản trị. Chỉ nói những gì demo được.',
    say: [
      'Những chức năng này đối chiếu đúng với code đang chạy. Người dùng: đăng ký OTP email, JWT và refresh, eKYC chờ Admin, đăng tin, lọc, chat realtime và đặt mua trong chat.',
      'Giao dịch có ba cách: escrow, chuyển khoản, tiền mặt. Có ảnh xác nhận nhận hàng, khiếu nại, ví người bán và rút tiền chờ duyệt.',
      'Phía quản trị: duyệt hoặc từ chối eKYC, ẩn tin, cảnh cáo, khóa, cấm, xử lý báo cáo và xuất PDF dashboard.',
    ],
    how: [
      'Đừng phóng đại. Yêu thích là local. Thông báo chưa FCM. Nói đúng sẽ đỡ bị hỏi xoáy.',
      'Nếu sắp demo: câu này là cầu nối “phần demo sẽ đi đúng luồng vừa nêu”.',
    ],
    cut: 'Bỏ slide. Một câu ở slide kết quả đã đủ.',
  },
  {
    no: 13,
    title: 'Kết quả đạt được',
    timeFull: '25–30 giây',
    timeShort: '20 giây',
    look: 'Nhìn bốn con số, rồi đọc luồng end-to-end một hơi.',
    say: [
      'Kết quả nhóm muốn nhấn mạnh: đây là hệ thống chạy được end-to-end trên thiết bị, không phải mô hình giấy.',
      'Ba tầng, năm schema, mười tám module NestJS, ba trụ cột eKYC – escrow – điểm tín nhiệm.',
      'Luồng đăng ký, eKYC, đăng tin, chat, thanh toán sandbox, hoàn tất đơn, cộng điểm, rút ví — chạy thông suốt.',
      'Tiền dùng bigint đồng nguyên. Access token mười lăm phút, refresh được rotate, mật khẩu bcrypt mười vòng.',
    ],
    how: [
      'Giọng kết, không giọng khoe. “Không phải mô hình giấy” nói một lần, đừng lặp.',
      'Repo chỉ nêu nếu Hội đồng muốn xem; không cần đọc URL.',
    ],
    cut: 'Một câu: chạy end-to-end từ đăng ký đến rút ví trên thiết bị.',
  },
  {
    no: 14,
    title: 'Hạn chế và hướng phát triển',
    timeFull: '35–45 giây',
    timeShort: '25 giây',
    look: 'Nói hạn chế trước, hướng phát triển sau. Đừng biện minh.',
    say: [
      'Nhóm xin nói thẳng những gì đồ án chưa làm.',
      'OTP đang lưu RAM nên restart server mất phiên đăng ký. Hoàn tiền VNPay hiện chỉ đổi trạng thái cơ sở dữ liệu, chưa gọi API refund. Firebase rules bản demo đang mở đọc ghi. Phân cực bình luận dùng lexicon khoảng bốn mươi sáu cụm, chưa đo độ chính xác. Chưa FCM, chưa đơn vị vận chuyển, chưa phân trang tin đăng.',
      'Hướng phát triển bám đúng hạn chế đó: Redis cho OTP, Firebase Auth kèm rule theo người trong cuộc, gọi refund VNPay, khóa dòng khi tạo đơn, FCM, đồng bộ yêu thích, liveness token do server phát, và tách việc cập nhật điểm khỏi trigger SQL nếu cần kiểm soát ở tầng ứng dụng.',
    ],
    how: [
      'Slide này lấy điểm thành thật. Nói hạn chế như kỹ sư, không như đang xin lỗi.',
      'Mỗi hạn chế đã có hướng xử lý — Hội đồng thấy nhóm biết đường đi tiếp, không phải bị động.',
      'Đừng tự nhận “hệ thống chưa hoàn thiện” chung chung. Nêu cụ thể từng mục.',
    ],
    cut: 'OTP RAM, refund chưa gọi API, Firebase rules mở, chưa FCM/vận chuyển. Hướng: Redis, refund thật, rule chặt.',
  },
  {
    no: 15,
    title: 'Kết thúc — cảm ơn Hội đồng',
    timeFull: '12–18 giây',
    timeShort: '10 giây',
    look: 'Nhìn Hội đồng, cúi đầu nhẹ. Im lặng một giây rồi ngồi.',
    say: [
      'Trên đây là phần trình bày của nhóm em về SafeMarket, với ba trụ cột eKYC, escrow và điểm tín nhiệm.',
      'Nhóm em xin cảm ơn quý Thầy Cô trong Hội đồng và sẵn sàng trả lời câu hỏi.',
    ],
    how: [
      'Không nói thêm “em xin phép kết thúc” lòng vòng. Hai câu là đủ.',
      'Sau khi cảm ơn, đứng yên, đợi Hội đồng chủ trì mời ngồi / bắt đầu vấn đáp.',
      'Không tắt slide. Để nguyên slide cảm ơn khi trả lời câu hỏi.',
    ],
    cut: 'Cảm ơn và sẵn sàng trả lời câu hỏi.',
  },
];

function slideSection(s) {
  return [
    heading(`Slide ${s.no}  ·  ${s.title}`, HeadingLevel.HEADING_1),
    labelLine('Thời lượng bản 8–10 phút:', s.timeFull),
    labelLine('Bản 5–6 phút:', s.timeShort),
    ...noteBlock('NHÌN SLIDE / THAO TÁC', [s.look]),
    ...speakBlock(s.say),
    ...noteBlock('CÁCH DIỄN ĐẠT', s.how),
    ...noteBlock('NẾU THIẾU GIỜ — nói một hơi', [s.cut]),
  ];
}

const children = [
  p([run('TRƯỜNG ĐẠI HỌC NGOẠI NGỮ – TIN HỌC TP. HỒ CHÍ MINH', { size: 22, color: MUTED, bold: true })], {
    align: AlignmentType.CENTER,
    after: 40,
  }),
  p([run('KHOA CÔNG NGHỆ THÔNG TIN', { size: 22, color: MUTED, bold: true })], {
    align: AlignmentType.CENTER,
    after: 200,
  }),
  p([run('KỊCH BẢN THUYẾT TRÌNH BẢO VỆ', { size: 36, bold: true, color: PURPLE })], {
    align: AlignmentType.CENTER,
    after: 80,
  }),
  p(
    [
      run(
        'Xây dựng ứng dụng sàn giao dịch trung gian SafeMarket tích hợp định danh điện tử eKYC',
        { size: 26, italics: true },
      ),
    ],
    { align: AlignmentType.CENTER, after: 200 },
  ),
  p([run('Sinh viên: Trương Trí Hiền  ·  Nguyễn Tấn Lộc', { size: 24 })], { align: AlignmentType.CENTER, after: 40 }),
  p([run('Ngành Công nghệ thông tin  ·  2026', { size: 22, color: MUTED })], { align: AlignmentType.CENTER, after: 40 }),
  p([run('Thời lượng nói: 5–10 phút  (bản chuẩn 8–10 phút, bản rút 5–6 phút)', { size: 22, color: PURPLE, bold: true })], {
    align: AlignmentType.CENTER,
    after: 40,
  }),
  p([run('Nguồn: SafeMarket_Slide_Bao_Ve.pptx  ·  15 slide', { size: 20, color: MUTED })], {
    align: AlignmentType.CENTER,
    after: 300,
  }),

  heading('1. Cách dùng kịch bản này'),
  p(
    'File này viết để đọc khi luyện, không phải để cầm lên đọc nguyên văn trước Hội đồng. Buổi bảo vệ: nhìn Hội đồng, liếc slide, nói theo ý. Chỉ học thuộc câu mở, câu kết, và ba câu then chốt của eKYC – escrow – điểm.',
    { size: 22, after: 160 },
  ),
  p([run('Ba nguyên tắc diễn đạt', { bold: true, size: 24, color: PURPLE })], { after: 80 }),
  p('Một, nói như kỹ sư đang giải thích hệ thống chạy thật — không phóng đại, không nhận là AI/ML.', { after: 80 }),
  p('Hai, mỗi slide chỉ có một câu “Hội đồng cần nhớ”. Câu đó nằm ở khối NÓI, thường là câu đầu hoặc câu cuối.', {
    after: 80,
  }),
  p(
    'Ba, nếu chủ tịch nhắc sắp hết giờ: nhảy sang bản rút ở cuối file. Bỏ slide 2, 7, 12; rút slide 5 và 11 còn một câu.',
    { after: 200 },
  ),
  p([run('Nhịp nói gợi ý', { bold: true, size: 24, color: PURPLE })], { after: 80 }),
  p(
    'Tiếng Việt bảo vệ khoảng 130–150 từ/phút nếu nói rõ. Bản đầy đủ dưới đây khoảng 1.150–1.250 từ nói, tương đương 8 đến 10 phút kể cả hơi dừng. Bản rút khoảng 700 từ, khoảng 5 đến 6 phút.',
    { after: 160 },
  ),
  p([run('Việc nên làm / không nên làm', { bold: true, size: 24, color: PURPLE })], { after: 120 }),
  makeTable(
    ['Nên', 'Không nên'],
    [
      [
        { text: 'Chào Hội đồng, nêu đề tài, rồi vào bài toán.' },
        { text: 'Đọc bullet trên slide từ trên xuống dưới.' },
      ],
      [
        { text: 'Nhấn ba trụ cột; dành ~50% thời gian cho slide 8–10.' },
        { text: 'Kể hết chức năng phụ (yêu thích, PDF) lúc đang thiếu giờ.' },
      ],
      [
        { text: 'Nói hạn chế cụ thể, kèm hướng xử lý.' },
        { text: 'Xin lỗi “em chưa kịp”, “code còn bug”, “em không nhớ”.' },
      ],
      [
        { text: 'Dừng 1 giây sau câu then chốt (Paid ≠ tiền về seller).' },
        { text: 'Nói nhanh bịt lỗi, nuốt chữ số (0,72; 0–1000; +20).' },
      ],
    ],
    [5040, 5040],
  ),
  p('', { after: 200 }),

  heading('2. Phân bổ thời gian'),
  p('Bảng dưới bám 15 slide trong file PowerPoint. Cộng các mốc “bản chuẩn” được khoảng 9 phút 30 giây, còn dư 30–90 giây nếu Hội đồng cho đủ 10 phút.', {
    after: 160,
  }),
  makeTable(
    ['Slide', 'Nội dung', '8–10 phút', '5–6 phút', 'Mức ưu tiên'],
    [
      [{ text: '1' }, { text: 'Bìa, chào Hội đồng' }, { text: '30 giây' }, { text: '20 giây' }, { text: 'Bắt buộc' }],
      [{ text: '2' }, { text: 'Mục lục' }, { text: '20 giây' }, { text: 'Bỏ' }, { text: 'Có thể bỏ' }],
      [{ text: '3' }, { text: 'Ba lỗ hổng C2C' }, { text: '55 giây' }, { text: '40 giây' }, { text: 'Cao' }],
      [{ text: '4' }, { text: 'Mục tiêu, phạm vi' }, { text: '40 giây' }, { text: '25 giây' }, { text: 'Cao' }],
      [{ text: '5' }, { text: 'So với Chợ Tốt' }, { text: '35 giây' }, { text: '20 giây' }, { text: 'Trung bình' }],
      [{ text: '6' }, { text: 'Kiến trúc 3 tầng' }, { text: '45 giây' }, { text: '35 giây' }, { text: 'Cao' }],
      [{ text: '7' }, { text: 'Công nghệ' }, { text: '25 giây' }, { text: 'Bỏ' }, { text: 'Có thể bỏ' }],
      [
        { text: '8', bold: true },
        { text: 'eKYC', bold: true },
        { text: '70 giây', bold: true },
        { text: '50 giây', bold: true },
        { text: 'Trọng tâm', bold: true, color: PURPLE },
      ],
      [
        { text: '9', bold: true },
        { text: 'Escrow + state máy', bold: true },
        { text: '70 giây', bold: true },
        { text: '50 giây', bold: true },
        { text: 'Trọng tâm', bold: true, color: PURPLE },
      ],
      [
        { text: '10', bold: true },
        { text: 'Điểm tín nhiệm', bold: true },
        { text: '55 giây', bold: true },
        { text: '40 giây', bold: true },
        { text: 'Trọng tâm', bold: true, color: PURPLE },
      ],
      [{ text: '11' }, { text: 'Cơ sở dữ liệu' }, { text: '30 giây' }, { text: '20 giây' }, { text: 'Trung bình' }],
      [{ text: '12' }, { text: 'Chức năng đã làm' }, { text: '25 giây' }, { text: 'Bỏ' }, { text: 'Có thể bỏ' }],
      [{ text: '13' }, { text: 'Kết quả' }, { text: '25 giây' }, { text: '20 giây' }, { text: 'Cao' }],
      [{ text: '14' }, { text: 'Hạn chế, hướng đi' }, { text: '40 giây' }, { text: '25 giây' }, { text: 'Cao' }],
      [{ text: '15' }, { text: 'Cảm ơn' }, { text: '15 giây' }, { text: '10 giây' }, { text: 'Bắt buộc' }],
      [
        { text: '', bold: true },
        { text: 'Tổng', bold: true },
        { text: '~9 phút 40 giây', bold: true },
        { text: '~5 phút 55 giây', bold: true },
        { text: '', bold: true },
      ],
    ],
    [900, 2880, 1980, 1980, 2340],
  ),
  p('', { after: 200 }),
  p(
    'Nếu Hội đồng cho đủ 10–12 phút (đúng ghi chú trên slide 2): giữ nguyên bản chuẩn, nới slide 8–9–10 thêm khoảng 15 giây mỗi slide — kể thêm một ví dụ, không kể thêm tính năng mới.',
    { after: 200, italics: true, color: MUTED },
  ),

  heading('3. Ba câu phải thuộc lòng'),
  p('Dù rút bài thế nào, ba câu sau vẫn nói đủ chữ:', { after: 120 }),
  p(
    'eKYC.  “Client không gọi thẳng FPT.AI. Người dùng phải Verified thì mới được mua và đăng tin.”',
    { after: 120, fill: SPEAK_BG, indent: 160 },
  ),
  p(
    'Escrow.  “Tiền không về tay người bán lúc Paid. Chỉ khi người mua xác nhận nhận hàng kèm ảnh, escrow mới Released và cộng vào ví.”',
    { after: 120, fill: SPEAK_BG, indent: 160 },
  ),
  p(
    'Điểm.  “Không phải mô hình học máy. Điểm mới bằng kẹp 0–1000 của điểm cũ cộng delta; user mới 500 điểm, hạng do trigger SQL gán lại.”',
    { after: 200, fill: SPEAK_BG, indent: 160 },
  ),

  heading('4. Kịch bản đầy đủ theo từng slide (8–10 phút)'),
  p('Khối nền tím nhạt là lời nói. Khối xám là cách diễn đạt và thao tác. Luyện 3 lần: lần 1 đọc, lần 2 nói không nhìn giấy, lần 3 bấm slide như bảo vệ.', {
    after: 160,
  }),
];

for (const s of slides) {
  children.push(...slideSection(s));
}

children.push(
  new Paragraph({ children: [new PageBreak()] }),
  heading('5. Bản rút gọn 5–6 phút — đọc liền mạch'),
  p(
    'Dùng khi bị nhắc hết giờ, hoặc vòng bảo vệ chỉ cho 5 phút. Bỏ slide 2, 7, 12. Bấm nhanh: 1 → 3 → 4 → 5 → 6 → 8 → 9 → 10 → 11 → 13 → 14 → 15.',
    { after: 160 },
  ),
  ...speakBlock([
    'Kính thưa Hội đồng, nhóm em gồm Trương Trí Hiền và Nguyễn Tấn Lộc xin trình bày khóa luận xây dựng sàn giao dịch trung gian SafeMarket tích hợp eKYC.',
    'Chợ C2C đồ cũ tại Việt Nam có ba lỗ hổng: danh tính yếu vì OTP và SIM rác; tín nhiệm năm sao dễ làm giả; tiền chuyển khoản tay nên nền tảng không giữ và không hoàn có kiểm soát. SafeMarket giải bằng eKYC, điểm theo hành vi, và escrow.',
    'Nhóm làm chợ đồ cũ trên Android Flutter, backend NestJS và SQL Server: đăng tin, chat, đặt hàng, thanh toán ký quỹ VNPay sandbox, ví người bán, điểm 0 đến 1000, và Admin duyệt. Client chính chưa iOS production; chưa vận chuyển thật, chưa FCM; cố ý không làm gợi ý sản phẩm AI.',
    'So với Chợ Tốt, nhóm kế thừa trải nghiệm mua bán nhưng thay OTP bằng eKYC bắt buộc, thay sao bằng điểm cộng sự kiện, thay chuyển khoản tay bằng giữ tiền đến khi nhận hàng.',
    'Kiến trúc ba tầng: Flutter gọi NestJS, không đụng SQL. SQL là sổ cái tiền và danh tính. Firebase chỉ là kênh chat realtime.',
    'eKYC bốn bước: OCR mặt trước, OCR mặt sau, liveness ML Kit trên máy, rồi Admin duyệt. API key FPT.AI nằm phía server. Chưa Verified thì không mua, không bán.',
    'Escrow: tạo đơn thì hàng Reserved; Paid thì tiền Holding; người bán gửi hàng; người mua xác nhận kèm ảnh thì Released vào ví. UNIQUE product_id chống bán trùng. Tranh chấp do Admin hoàn buyer hoặc giải ngân seller.',
    'Điểm không phải machine learning. S mới bằng kẹp 0–1000 của S cộng delta, khởi tạo 500. Hoàn tất đơn cộng 20, năm sao cộng 30, báo cáo nặng trừ 50. Trigger SQL cập nhật hạng Bronze đến Diamond.',
    'Kết quả là hệ thống chạy end-to-end trên thiết bị. Hạn chế thật: OTP lưu RAM, refund VNPay chưa gọi API, Firebase rules bản demo đang mở, chưa FCM và vận chuyển. Hướng tiếp theo bám đúng các điểm đó.',
    'Nhóm em xin cảm ơn Hội đồng và sẵn sàng trả lời câu hỏi.',
  ]),

  heading('6. Câu chuyển sang vấn đáp'),
  p('Sau slide cảm ơn, nếu chủ tịch mời hỏi, mở bằng một câu ngắn rồi trả lời đúng trọng tâm. Không mở lại toàn bộ bài.', {
    after: 120,
  }),
  makeTable(
    ['Nếu Hội đồng hỏi', 'Cách mở miệng'],
    [
      [
        { text: 'Thuật toán của đề tài là gì?' },
        {
          text: 'Dạ, thuật toán cốt lõi là mô hình điểm có ngưỡng hạng, cộng cơ chế khóa hàng và ký quỹ. Không phải recommendation.',
        },
      ],
      [
        { text: 'Tiền đang nằm ở đâu?' },
        { text: 'Dạ, lúc Paid tiền ở trạng thái Holding. Seller chưa nhận STK. Completed kèm ảnh mới vào ví.' },
      ],
      [
        { text: 'Hai người mua cùng một món thì sao?' },
        { text: 'Dạ, UNIQUE product_id trên Orders, kèm Reserved. Đơn hủy mới bán lại.' },
      ],
      [
        { text: 'eKYC có phải tự viết OCR?' },
        { text: 'Dạ không. OCR FPT.AI; app làm UX và liveness; NestJS giữ session và khóa API.' },
      ],
      [
        { text: 'Chat mất thì mất đơn không?' },
        { text: 'Dạ không. Chat Firebase; đơn, tiền, điểm ở SQL.' },
      ],
      [
        { text: 'Hệ thống đã production chưa?' },
        { text: 'Dạ đây là đồ án chạy end-to-end, VNPay sandbox, một số rule demo còn mở — nhóm đã nêu ở hạn chế.' },
      ],
    ],
    [3600, 6480],
  ),
  p('', { after: 240 }),
  p(
    'Chúc nhóm bảo vệ tốt. Nói chậm hơn một nấc so với lúc luyện — trước Hội đồng ai cũng nói nhanh hơn mình tưởng.',
    { after: 80, italics: true, color: MUTED, align: AlignmentType.CENTER },
  ),
);

const doc = new Document({
  styles: {
    default: {
      document: {
        run: { font: FONT, size: 22 },
      },
    },
  },
  sections: [
    {
      properties: {
        page: {
          size: { width: 11906, height: 16838 },
          margin: { top: 1134, bottom: 1134, left: 1134, right: 1134 },
        },
      },
      headers: {
        default: new Header({
          children: [
            new Paragraph({
              alignment: AlignmentType.RIGHT,
              children: [run('SafeMarket  ·  Kịch bản thuyết trình bảo vệ  ·  5–10 phút', { size: 16, color: MUTED })],
            }),
          ],
        }),
      },
      footers: {
        default: new Footer({
          children: [
            new Paragraph({
              alignment: AlignmentType.CENTER,
              children: [
                run('Trương Trí Hiền  ·  Nguyễn Tấn Lộc  ·  Trang ', { size: 16, color: MUTED }),
                new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 16, color: MUTED }),
                run(' / ', { size: 16, color: MUTED }),
                new TextRun({ children: [PageNumber.TOTAL_PAGES], font: FONT, size: 16, color: MUTED }),
              ],
            }),
          ],
        }),
      },
      children,
    },
  ],
});

async function main() {
  const buf = await Packer.toBuffer(doc);
  const outDir = path.resolve(__dirname, '..', '..', 'docs_docx');
  fs.mkdirSync(outDir, { recursive: true });
  const name = 'Kich_Ban_Thuyet_Trinh_SafeMarket_Bao_Ve.docx';
  const p1 = path.join(outDir, name);
  const p2 = path.join('C:\\Users\\letan\\Downloads', name);
  fs.writeFileSync(p1, buf);
  fs.writeFileSync(p2, buf);
  console.log('WROTE', p1);
  console.log('WROTE', p2);
  console.log('BYTES', buf.length);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
