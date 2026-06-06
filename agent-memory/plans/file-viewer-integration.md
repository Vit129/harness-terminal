# แผนงานการสร้างระบบพรีวิวและแสดงผลไฟล์ (File Viewer & Preview Integration Plan)

แผนงานนี้ระบุแนวทางและสถาปัตยกรรมทางซอฟต์แวร์ในการนำฟีเจอร์แสดงผลไฟล์ (File Viewer) มาใช้งานใน Harness Terminal โดยผสมผสานระบบ **macOS Quick Look Framework** เพื่อช่วยรองรับไฟล์ตระกูล Office, PDF, Image และ Media และระบบ Webview-Hybrid/Native สำหรับซอร์สโค้ดและ Markdown

---

## 1. เบื้องหลังการทำงานของระบบพรีวิวบน macOS (Under the Hood: macOS Quick Look)

ในการทำความเข้าใจว่า macOS ทำอย่างไรถึงรองรับการพรีวิวไฟล์ได้อย่างมหาศาล ระบบปฏิบัติการ macOS ใช้สถาปัตยกรรมดังนี้:

### 1.1 โครงสร้างการทำงานของ Quick Look (Quick Look Architecture)
* **กลไกภายนอกโพรเซส (Out-of-Process Generation):** การพรีวิวไม่ได้รันอยู่ในหน่วยความจำของแอปพลิเคชันเราโดยตรง แต่ควบคุมผ่านระบบ Daemon ของ OS ที่ชื่อ **`quicklookd`** เพื่อความปลอดภัยระดับ Sandbox (ป้องกันไม่ให้แอปหลักพังหรือโดนเจาะระบบหากเปิดไฟล์ PDF/Office ที่ประสงค์ร้าย)
* **Uniform Type Identifiers (UTIs):** macOS ใช้รหัส UTI (เช่น `public.jpeg`, `com.adobe.pdf`, `org.openxmlformats.spreadsheetml.sheet`) ในการระบุประเภทไฟล์ แทนการใช้เพียงนามสกุลไฟล์ธรรมดา
* **ปลั๊กอินและแอปพลิเคชันเสริม (Quick Look Preview Extensions):**
  * ระบบปฏิบัติการจะมีตัว Preview Generator พื้นฐาน (เช่น PDF, Text, Common Images)
  * แอปพลิเคชันอื่น ๆ ในเครื่อง (เช่น Microsoft Excel, Adobe Acrobat) สามารถลงทะเบียน **Quick Look Preview Extension** (`QLPreviewProvider`) เพื่อบอกระบบว่าสามารถช่วยวาดภาพพรีวิวสำหรับประเภท UTI นั้น ๆ ได้ 
  * เมื่อเราขอเปิดพรีวิวไฟล์ผ่าน `QLPreviewView` ระบบ macOS จะไปจับคู่ UTI ของไฟล์กับ Extension ที่เหมาะสมที่สุดในเครื่อง แล้วดึงมาเรนเดอร์ลงบนเฟรมการพรีวิวของเราโดยอัตโนมัติ

### 1.2 สองคลาสหลักในการใช้งาน (QLPreviewPanel vs. QLPreviewView)
* **`QLPreviewPanel`:** หน้าต่างพรีวิวแชร์ร่วมของแอป (แบบเดียวกับปุ่ม Spacebar ใน Finder) ทำงานโดยการสืบทอดโปรโตคอล `QLPreviewPanelDataSource`
* **`QLPreviewView`:** คลาสย่อยของ `NSView` (AppKit) หรือสามารถห่อหุ้มใน SwiftUI เพื่อนำมาฝังลงในผังหน้าจอหลักของแอปพลิเคชันโดยตรง (Inline Preview) เหมาะสำหรับการทำแผงพรีวิวแบบสลับตามไฟล์ที่ผู้ใช้เลือกใน File Tree

---

## 2. การกำหนดลำดับขั้นการคัดแยกประเภทไฟล์ (File Routing Model)

เราจะออกแบบโมเดลการเลือกตัวเรนเดอร์ตามสเปกของไฟล์ (UTI) ด้วยการเชื่อมโยงระบบ `UniformTypeIdentifiers` ของแอปเปิ้ล:

```swift
import Foundation
import UniformTypeIdentifiers

enum FilePreviewCategory {
    case sourceCode(language: String) // ไฟล์โค้ดโปรแกรม
    case markdown                     // ไฟล์ Markdown (.md)
    case spreadsheet                  // ตารางข้อมูลดิบ (.csv, .tsv)
    case nativePreviewable            // ไฟล์ที่ macOS Quick Look ถอดรหัสได้ดีมาก (PDF, Excel, Word, PPT, Image, Audio, Video)
    case unsupported                  // ไฟล์ที่ไม่รู้จัก
}
```

---

## 3. แผนการแบ่งแทร็กการพัฒนา (Development Tracks)

```text
                               File Selection
                                     |
                +--------------------+--------------------+
                |                                         |
     Category: .sourceCode / .markdown            Category: .nativePreviewable
                |                                         |
        [ Monaco Editor / Down HTML ]             [ QLPreviewView Container ]
                |                                         |
         - Syntax Highlighting                     - Excel, PDF, Word Previews
         - LSP Integration (JSON-RPC)              - High-Fidelity Rendering
```

### Track A: ตัววิเคราะห์และพรีวิวไฟล์ของระบบปฏิบัติการ (Quick Look Track)
* **เป้าหมาย:** รองรับไฟล์ Excel (`.xlsx`), Word (`.docx`), PDF (`.pdf`), รูปภาพ และมัลติมีเดีย
* **วิธีการ:**
  1. นำเข้าเฟรมเวิร์ก `Quartz` และ `QuickLookUI`
  2. สร้างคลาส `QuickLookPreviewView` ครอบการทำงานของ `QLPreviewView`
  3. ตั้งค่าการอัปเดตไฟล์โดยการผูกกับโปรโตคอล `QLPreviewItem`
  4. ทำระบบ Fallback ไปยัง Quick Look เสมอ หากประเภทไฟล์ไม่ตรงกับกลุ่มโค้ดหรือข้อความ

### Track B: ตัวแก้ไขโค้ดและการรวมระบบ LSP (Source Editor & LSP Track)
* **เป้าหมาย:** แสดงผลซอร์สโค้ดที่มีความสามารถระดับ IDE (เช่น การระบายสี, ค้นหาคำ, จัดย่อหน้า และ Autocomplete)
* **วิธีการ:**
  1. สร้างตัวจัดการโหลด **Monaco Editor** ในเครื่องลงบน `WKWebView` เพื่อใช้เป็นแกนของ Editor
  2. สร้างการเชื่อมต่อโพรเซสย่อย (Subprocess) ไปยัง Language Server ในเครื่องคอมพิวเตอร์ผู้ใช้ผ่านทาง JSON-RPC (เช่น เชื่อมต่อ `sourcekit-lsp` เมื่อผู้ใช้เปิดไฟล์ Swift)
  3. รับส่งข้อมูล Autocomplete, Diagnostics, และ Hover ข้ามโพรเซสจาก Swift เข้าสู่ Monaco ใน WebView

### Track C: ตัวเรนเดอร์เอกสารตารางและมาร์กดาวน์ (CSV & Markdown Track)
* **เป้าหมาย:** แสดงผลเอกสาร Markdown สวยงาม และตารางข้อมูล CSV ที่โต้ตอบได้
* **วิธีการ:**
  1. สำหรับ Markdown: นำเข้า Cmark/Swift-Markdown แปลงข้อความเป็น HTML และโหลดด้วย CSS ธีมหลักผ่าน `WKWebView`
  2. สำหรับ CSV: สร้างโมเดลกริดง่าย ๆ นำมาแสดงผลผ่าน `NSTableView` เพื่อให้สามารถกดฟิลเตอร์หรือจัดเรียงคอลัมน์ข้อมูลได้ทันที

---

## 4. โครงสร้างโค้ดและอินเตอร์เฟสต้นแบบ (Swift Code Boilerplate)

### 4.1 ตัวจัดการควบคุมกลยุทธ์การพรีวิว (File Preview Strategy Protocol)
```swift
import AppKit

protocol FilePreviewStrategy: AnyObject {
    var contentView: NSView { get }
    func previewFile(at url: URL) throws
    func handleSearch(query: String)
    func cleanUp()
}
```

### 4.2 คอนโทรลเลอร์แสดงผลไฟล์หลัก (FileViewerViewController)
```swift
import AppKit
import UniformTypeIdentifiers

class FileViewerViewController: NSViewController {
    private let containerView = NSView()
    private var activeStrategy: FilePreviewStrategy?
    
    override func loadView() {
        view = NSView()
        view.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
    
    func openFile(at url: URL) {
        // 1. เคลียร์มุมมองการพรีวิวเดิม
        activeStrategy?.cleanUp()
        activeStrategy?.contentView.removeFromSuperview()
        
        // 2. ตรวจสอบ UTI และเลือกกลยุทธ์การพรีวิว
        let strategy = resolveStrategy(for: url)
        self.activeStrategy = strategy
        
        // 3. แนบมุมมองใหม่เข้าหน้าจอ
        let previewView = strategy.contentView
        previewView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(previewView)
        
        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: containerView.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            previewView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
        
        // 4. สั่งโหลดไฟล์
        do {
            try strategy.previewFile(at: url)
        } catch {
            showErrorState(error)
        }
    }
    
    private func resolveStrategy(for url: URL) -> FilePreviewStrategy {
        let extensionName = url.pathExtension.lowercased()
        
        // กรณีพิเศษ: Markdown
        if ["md", "markdown"].contains(extensionName) {
            return MarkdownPreviewStrategy()
        }
        
        // กรณีพิเศษ: CSV/Spreadsheets ทั่วไป
        if ["csv", "tsv"].contains(extensionName) {
            return CSVTablePreviewStrategy()
        }
        
        // ตรวจสอบ UTI ผ่านระบบปฏิบัติการ macOS
        if let utType = UTType(filenameExtension: extensionName) {
            if utType.conforms(to: .sourceCode) || utType.conforms(to: .text) {
                return SourceCodePreviewStrategy(language: extensionName)
            }
        }
        
        // Fallback ไปใช้ Quick Look สำหรับรูปภาพ, เสียง, PDF, Excel และ Word
        return macOSQuickLookStrategy()
    }
    
    private func showErrorState(_ error: Error) {
        // แสดงหน้าจอระบุข้อผิดพลาดพรีวิวไม่ได้
    }
}
```

### 4.3 ตัวพรีวิวเนทีฟด้วย Quick Look (macOSQuickLookStrategy)
```swift
import Cocoa
import Quartz

class macOSQuickLookStrategy: NSObject, FilePreviewStrategy {
    let contentView = NSView()
    private var inlinePreview: QLPreviewView?
    
    func previewFile(at url: URL) throws {
        inlinePreview?.removeFromSuperview()
        
        // สร้างเฟรมของ QLPreviewView
        let qlView = QLPreviewView(frame: contentView.bounds, style: .normal)
        qlView.translatesAutoresizingMaskIntoConstraints = false
        
        // มอบหมาย URL ให้ระบบ Quick Look ทำการโหลดไฟล์นอกโพรเซสผ่าน quicklookd
        qlView.previewItem = url as QLPreviewItem
        
        contentView.addSubview(qlView)
        self.inlinePreview = qlView
        
        NSLayoutConstraint.activate([
            qlView.topAnchor.constraint(equalTo: contentView.topAnchor),
            qlView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            qlView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            qlView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }
    
    func handleSearch(query: String) {
        // ส่งต่อการค้นหาไม่ได้เนื่องจาก Quick Look เป็น Sandbox แบบปิด (Read-Only)
    }
    
    func cleanUp() {
        inlinePreview?.removeFromSuperview()
        inlinePreview = nil
    }
}
```

---

## 5. การทดสอบด้วยเคสพรีวิว (Manual Verification Cases)

* **เคส PDF & Images:** เปิดไฟล์ PDF และรูปภาพขนาดใหญ่ ต้องจัดสัดส่วนและย่อขยายหน้าตามขนาดหน้าจอได้โดยอัตโนมัติ
* **เคส Excel & Word:** เปิดไฟล์ `.xlsx` และ `.docx` โครงร่างของตารางและฟอนต์ต้องอ่านได้ชัดเจนเทียบเท่าแอปพลิเคชันตัวจริง
* **เคส Source Code & LSP:** เปิดไฟล์ภาษา Swift และเปิดใช้งานตัวช่วยวิเคราะห์ โดยตรวจสอบสถานะของ Process LSP Server ว่ารันได้เสร็จสมบูรณ์
* **เคส Markdown:** เปิดไฟล์ `.md` และลิงก์ภายในหน้าพรีวิวต้องกดคลิกเปลี่ยนหน้าได้ถูกต้อง
* **เคส CSV:** เปิดตารางขนาด 5,000 แถว ระบบสแกนข้อมูลและเรนเดอร์ในตาราง Table View ได้อย่างว่องไวและลื่นไหล
