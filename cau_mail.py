"""
CAU Webmail (IMAP) Service for UNIBODY.
Connects directly to imap.mail.uni-kiel.de via SSL (port 993) using the student's CAU credentials.
Provides high-performance batch fetching, snippet extraction, HTML/text rendering,
attachments handling, folder management, and read/unread status updates.
"""

import email
import imaplib
import re
import ssl
import time
from email.header import decode_header
from email.utils import parsedate_to_datetime
from typing import Any, Dict, List, Optional, Tuple

IMAP_HOST = "imap.mail.uni-kiel.de"
IMAP_PORT = 993

FOLDER_NAMES_DE = {
    "INBOX": "Posteingang",
    "SENT": "Gesendet",
    "DRAFTS": "Entwürfe",
    "ARCHIVES": "Archiv",
    "SPAM": "Spam / Junk",
    "TRASH": "Papierkorb",
}

FOLDER_ICONS = {
    "INBOX": "📬",
    "SENT": "📤",
    "DRAFTS": "📝",
    "ARCHIVES": "🗄️",
    "SPAM": "⚠️",
    "TRASH": "🗑️",
}


def decode_mime(header_val: Optional[str]) -> str:
    """Decodes MIME encoded-word strings into a clean unicode string."""
    if not header_val:
        return ""
    try:
        dh = decode_header(header_val)
        parts = []
        for text, enc in dh:
            if isinstance(text, bytes):
                parts.append(text.decode(enc or "utf-8", errors="replace"))
            else:
                parts.append(str(text))
        return "".join(parts).strip()
    except Exception:
        return str(header_val).strip()


def sanitize_html(html_str: str) -> str:
    """
    Sanitizes HTML content to remove scripts, iframes, inline event handlers,
    while preserving styling, layout, typography and links.
    """
    if not html_str:
        return ""
    # Strip script tags
    s = re.sub(r"(?is)<script.*?>.*?</script>", "", html_str)
    # Strip dangerous tags
    s = re.sub(r"(?is)<(iframe|embed|object|base).*?>", "", s)
    # Strip on* event handlers (e.g. onerror=..., onclick=...)
    s = re.sub(r"(?i)\s+on[a-z]+\s*=\s*(\"[^\"]*\"|'[^']*'|[^\s>]+)", "", s)
    # Add target="_blank" and rel="noopener noreferrer" to links
    s = re.sub(r"(?i)<a\s+href=", '<a target="_blank" rel="noopener noreferrer" href=', s)
    return s


def clean_snippet(raw_bytes: bytes) -> str:
    """Extracts a clean, human-readable preview snippet from raw body text or multipart snippet."""
    if not raw_bytes:
        return ""
    try:
        txt = raw_bytes.decode("utf-8", errors="replace")
        lines = [
            l.strip()
            for l in txt.splitlines()
            if l.strip()
            and not l.startswith("--")
            and not l.startswith("Content-")
            and "multi-part message" not in l.lower()
        ]
        clean = " ".join(lines)
        clean = re.sub(r"<[^>]+>", " ", clean)
        clean = re.sub(r"\s+", " ", clean).strip()
        return clean[:140]
    except Exception:
        return ""


def create_imap_client(username: str, password: str, timeout: int = 10) -> imaplib.IMAP4_SSL:
    ctx = ssl.create_default_context()
    client = imaplib.IMAP4_SSL(IMAP_HOST, IMAP_PORT, ssl_context=ctx, timeout=timeout)
    client.login(username, password)
    return client


def get_mail_status(username: str, password: str) -> Dict[str, Any]:
    """Fast check for total and unread email count in INBOX."""
    if not username or not password:
        return {"ok": False, "error": "Keine CAU-Zugangsdaten konfiguriert", "needs_login": True}

    client = None
    try:
        client = create_imap_client(username, password, timeout=6)
        status, res = client.status("INBOX", "(MESSAGES UNSEEN)")
        total = 0
        unseen = 0
        if status == "OK" and res:
            text = res[0].decode("utf-8", errors="ignore")
            m_tot = re.search(r"MESSAGES\s+(\d+)", text)
            m_uns = re.search(r"UNSEEN\s+(\d+)", text)
            if m_tot:
                total = int(m_tot.group(1))
            if m_uns:
                unseen = int(m_uns.group(1))
        return {
            "ok": True,
            "username": username,
            "email": f"{username}@mail.uni-kiel.de",
            "host": IMAP_HOST,
            "total_inbox": total,
            "unread_inbox": unseen,
        }
    except Exception as e:
        return {"ok": False, "error": str(e)}
    finally:
        if client:
            try:
                client.logout()
            except Exception:
                pass


def get_mail_folders(username: str, password: str) -> Dict[str, Any]:
    """Lists IMAP folders with friendly German labels, icons, and counts."""
    if not username or not password:
        return {"ok": False, "error": "Keine CAU-Zugangsdaten konfiguriert", "needs_login": True}

    client = None
    try:
        client = create_imap_client(username, password, timeout=8)
        typ, folder_list = client.list()
        folders = []
        if typ == "OK":
            for f in folder_list:
                line = f.decode("utf-8", errors="replace")
                # Format: (\Flags) "delimiter" "FolderName"
                parts = line.split(' "." ')
                if len(parts) >= 2:
                    raw_name = parts[-1].strip().strip('"')
                else:
                    raw_name = line.split()[-1].strip('"')

                name_upper = raw_name.upper()
                display_name = FOLDER_NAMES_DE.get(name_upper, raw_name)
                icon = FOLDER_ICONS.get(name_upper, "📁")

                # Fetch counts
                total = 0
                unseen = 0
                try:
                    s_status, s_res = client.status(f'"{raw_name}"', "(MESSAGES UNSEEN)")
                    if s_status == "OK" and s_res:
                        s_text = s_res[0].decode("utf-8", errors="ignore")
                        m_tot = re.search(r"MESSAGES\s+(\d+)", s_text)
                        m_uns = re.search(r"UNSEEN\s+(\d+)", s_text)
                        if m_tot:
                            total = int(m_tot.group(1))
                        if m_uns:
                            unseen = int(m_uns.group(1))
                except Exception:
                    pass

                folders.append({
                    "id": raw_name,
                    "name": display_name,
                    "icon": icon,
                    "total": total,
                    "unseen": unseen,
                })

        # Ensure INBOX is first
        folders.sort(key=lambda x: (0 if x["id"].upper() == "INBOX" else 1, x["name"]))

        return {
            "ok": True,
            "username": username,
            "email": f"{username}@mail.uni-kiel.de",
            "folders": folders,
        }
    except Exception as e:
        return {"ok": False, "error": str(e)}
    finally:
        if client:
            try:
                client.logout()
            except Exception:
                pass


def get_mail_list(
    username: str,
    password: str,
    folder: str = "INBOX",
    limit: int = 50,
    offset: int = 0,
    search_query: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Fetches email headers and snippets for the given folder, sorted newest first.
    Uses batch IMAP fetching for fast response (< 0.2s).
    """
    if not username or not password:
        return {"ok": False, "error": "Keine CAU-Zugangsdaten konfiguriert", "needs_login": True}

    client = None
    try:
        client = create_imap_client(username, password, timeout=12)
        sel_stat, sel_data = client.select(f'"{folder}"', readonly=True)
        if sel_stat != "OK":
            return {"ok": False, "error": f"Ordner '{folder}' konnte nicht geöffnet werden"}

        # Search query or ALL
        if search_query and search_query.strip():
            sq = search_query.strip()
            # Search subject or from or body
            status, data = client.search(None, f'(OR SUBJECT "{sq}" FROM "{sq}")')
        else:
            status, data = client.search(None, "ALL")

        if status != "OK" or not data or not data[0]:
            return {"ok": True, "folder": folder, "total": 0, "messages": []}

        all_ids = data[0].split()
        total_count = len(all_ids)

        # Newest first (reverse list)
        rev_ids = list(reversed(all_ids))
        paged_ids = rev_ids[offset : offset + limit]

        if not paged_ids:
            return {"ok": True, "folder": folder, "total": total_count, "messages": []}

        # Batch fetch headers, flags, and text snippet
        batch_seq = b",".join(paged_ids)
        fetch_query = "(FLAGS RFC822.SIZE BODY.PEEK[HEADER.FIELDS (SUBJECT FROM TO DATE MESSAGE-ID CONTENT-TYPE)] BODY.PEEK[TEXT]<0.200>)"
        f_stat, f_data = client.fetch(batch_seq, fetch_query)

        # Parse fetch responses
        messages_by_id: Dict[str, Dict[str, Any]] = {}
        for mid in paged_ids:
            messages_by_id[mid.decode()] = {
                "id": mid.decode(),
                "subject": "(Kein Betreff)",
                "from": "",
                "from_name": "",
                "from_email": "",
                "to": "",
                "date": "",
                "date_human": "",
                "snippet": "",
                "is_seen": False,
                "is_flagged": False,
                "has_attachment": False,
                "size_bytes": 0,
            }

        curr_id = None
        for item in f_data:
            if isinstance(item, tuple) and len(item) == 2:
                header_part = item[0]
                content = item[1]

                # Extract ID from start of header_part (e.g. b'117 (FLAGS...')
                m_id = re.search(rb"^\s*(\d+)\s+", header_part)
                if m_id:
                    curr_id = m_id.group(1).decode()

                if curr_id and curr_id in messages_by_id:
                    # Check flags
                    if b"\\Seen" in header_part:
                        messages_by_id[curr_id]["is_seen"] = True
                    if b"\\Flagged" in header_part:
                        messages_by_id[curr_id]["is_flagged"] = True

                    # Check size
                    m_size = re.search(rb"RFC822\.SIZE\s+(\d+)", header_part)
                    if m_size:
                        messages_by_id[curr_id]["size_bytes"] = int(m_size.group(1))

                    if b"HEADER.FIELDS" in header_part:
                        try:
                            msg = email.message_from_bytes(content)
                            subj = decode_mime(msg.get("subject", "(Kein Betreff)"))
                            from_raw = decode_mime(msg.get("from", ""))
                            to_raw = decode_mime(msg.get("to", ""))
                            date_raw = msg.get("date", "")
                            ctype = msg.get("content-type", "")

                            # Extract sender name and email
                            from_name = from_raw
                            from_email = from_raw
                            m_mail = re.search(r"<([^>]+)>", from_raw)
                            if m_mail:
                                from_email = m_mail.group(1).strip()
                                from_name = from_raw.replace(f"<{from_email}>", "").strip().strip('"').strip("'")
                                if not from_name:
                                    from_name = from_email

                            date_human = date_raw
                            try:
                                dt = parsedate_to_datetime(date_raw)
                                date_human = dt.strftime("%d.%m.%Y %H:%M")
                            except Exception:
                                pass

                            messages_by_id[curr_id]["subject"] = subj
                            messages_by_id[curr_id]["from"] = from_raw
                            messages_by_id[curr_id]["from_name"] = from_name
                            messages_by_id[curr_id]["from_email"] = from_email
                            messages_by_id[curr_id]["to"] = to_raw
                            messages_by_id[curr_id]["date"] = date_raw
                            messages_by_id[curr_id]["date_human"] = date_human
                            if "multipart/mixed" in ctype.lower() or "multipart/related" in ctype.lower():
                                messages_by_id[curr_id]["has_attachment"] = True
                        except Exception:
                            pass
                    elif b"BODY[TEXT]" in header_part:
                        try:
                            messages_by_id[curr_id]["snippet"] = clean_snippet(content)
                        except Exception:
                            pass
            elif isinstance(item, bytes):
                # May contain FLAGS (e.g. `117 (FLAGS (\\Seen))`)
                m_id = re.search(rb"\b(\d+)\s+FETCH", item)
                if m_id:
                    curr_id = m_id.group(1).decode()
                    if curr_id in messages_by_id:
                        if b"\\Seen" in item:
                            messages_by_id[curr_id]["is_seen"] = True
                        if b"\\Flagged" in item:
                            messages_by_id[curr_id]["is_flagged"] = True

        # Assemble in original reverse order
        ordered_messages = [messages_by_id[mid.decode()] for mid in paged_ids if mid.decode() in messages_by_id]

        return {
            "ok": True,
            "folder": folder,
            "total": total_count,
            "limit": limit,
            "offset": offset,
            "messages": ordered_messages,
        }
    except Exception as e:
        return {"ok": False, "error": str(e)}
    finally:
        if client:
            try:
                client.logout()
            except Exception:
                pass


def get_mail_message(
    username: str,
    password: str,
    message_id: str,
    folder: str = "INBOX",
    mark_seen: bool = True,
) -> Dict[str, Any]:
    """
    Fetches and parses a single complete email message with HTML body,
    plain text body, attachments metadata, sender/recipient info, and headers.
    """
    if not username or not password:
        return {"ok": False, "error": "Keine CAU-Zugangsdaten konfiguriert", "needs_login": True}

    client = None
    try:
        client = create_imap_client(username, password, timeout=15)
        sel_stat, sel_data = client.select(f'"{folder}"', readonly=False)
        if sel_stat != "OK":
            return {"ok": False, "error": f"Ordner '{folder}' konnte nicht geöffnet werden"}

        typ, msg_data = client.fetch(str(message_id), "(FLAGS RFC822)")
        if typ != "OK" or not msg_data:
            return {"ok": False, "error": f"E-Mail mit ID {message_id} nicht gefunden"}

        raw_rfc822 = None
        flags_raw = b""
        for item in msg_data:
            if isinstance(item, tuple) and len(item) == 2:
                flags_raw = item[0]
                raw_rfc822 = item[1]
                break

        if not raw_rfc822:
            return {"ok": False, "error": "Leerer E-Mail Inhalt"}

        msg = email.message_from_bytes(raw_rfc822)

        subj = decode_mime(msg.get("subject", "(Kein Betreff)"))
        from_raw = decode_mime(msg.get("from", ""))
        to_raw = decode_mime(msg.get("to", ""))
        cc_raw = decode_mime(msg.get("cc", ""))
        reply_to = decode_mime(msg.get("reply-to", ""))
        date_raw = msg.get("date", "")

        from_name = from_raw
        from_email = from_raw
        m_mail = re.search(r"<([^>]+)>", from_raw)
        if m_mail:
            from_email = m_mail.group(1).strip()
            from_name = from_raw.replace(f"<{from_email}>", "").strip().strip('"').strip("'")
            if not from_name:
                from_name = from_email

        date_human = date_raw
        date_iso = ""
        try:
            dt = parsedate_to_datetime(date_raw)
            date_human = dt.strftime("%d. %B %Y, %H:%M Uhr")
            date_iso = dt.isoformat()
        except Exception:
            pass

        body_text = ""
        body_html = ""
        attachments = []
        att_counter = 0

        if msg.is_multipart():
            for part in msg.walk():
                ctype = part.get_content_type().lower()
                cdisp = str(part.get("Content-Disposition") or "").lower()
                fname = part.get_filename()

                if fname or "attachment" in cdisp:
                    filename = decode_mime(fname) or f"Anhang_{att_counter+1}"
                    payload = part.get_payload(decode=True) or b""
                    size_bytes = len(payload)
                    attachments.append({
                        "index": att_counter,
                        "filename": filename,
                        "size_bytes": size_bytes,
                        "size_human": format_file_size(size_bytes),
                        "content_type": ctype,
                    })
                    att_counter += 1
                elif ctype == "text/html" and not body_html:
                    payload = part.get_payload(decode=True)
                    if payload:
                        charset = part.get_content_charset() or "utf-8"
                        body_html = payload.decode(charset, errors="replace")
                elif ctype == "text/plain" and not body_text:
                    payload = part.get_payload(decode=True)
                    if payload:
                        charset = part.get_content_charset() or "utf-8"
                        body_text = payload.decode(charset, errors="replace")
        else:
            ctype = msg.get_content_type().lower()
            payload = msg.get_payload(decode=True)
            charset = msg.get_content_charset() or "utf-8"
            decoded_text = payload.decode(charset, errors="replace") if payload else ""
            if ctype == "text/html":
                body_html = decoded_text
            else:
                body_text = decoded_text

        # Sanitize HTML
        clean_html = sanitize_html(body_html) if body_html else ""

        # Mark seen on server if requested
        if mark_seen:
            try:
                client.store(str(message_id), "+FLAGS", "\\Seen")
            except Exception:
                pass

        return {
            "ok": True,
            "message": {
                "id": str(message_id),
                "folder": folder,
                "subject": subj,
                "from": from_raw,
                "from_name": from_name,
                "from_email": from_email,
                "to": to_raw,
                "cc": cc_raw,
                "reply_to": reply_to,
                "date": date_raw,
                "date_human": date_human,
                "date_iso": date_iso,
                "body_html": clean_html,
                "body_text": body_text,
                "has_html": bool(clean_html),
                "has_text": bool(body_text),
                "attachments": attachments,
                "is_seen": True if mark_seen else (b"\\Seen" in flags_raw),
                "is_flagged": b"\\Flagged" in flags_raw,
            },
        }
    except Exception as e:
        return {"ok": False, "error": str(e)}
    finally:
        if client:
            try:
                client.logout()
            except Exception:
                pass


def get_mail_attachment_data(
    username: str,
    password: str,
    message_id: str,
    attachment_index: int,
    folder: str = "INBOX",
) -> Tuple[Optional[bytes], str, str]:
    """Retrieves raw attachment bytes, content type and filename for download."""
    client = None
    try:
        client = create_imap_client(username, password, timeout=20)
        client.select(f'"{folder}"', readonly=True)
        typ, msg_data = client.fetch(str(message_id), "(RFC822)")
        if typ != "OK" or not msg_data:
            return None, "", ""

        raw_rfc822 = None
        for item in msg_data:
            if isinstance(item, tuple) and len(item) == 2:
                raw_rfc822 = item[1]
                break

        if not raw_rfc822:
            return None, "", ""

        msg = email.message_from_bytes(raw_rfc822)
        curr_idx = 0
        for part in msg.walk():
            fname = part.get_filename()
            cdisp = str(part.get("Content-Disposition") or "").lower()
            if fname or "attachment" in cdisp:
                if curr_idx == int(attachment_index):
                    filename = decode_mime(fname) or f"attachment_{curr_idx}"
                    payload = part.get_payload(decode=True) or b""
                    ctype = part.get_content_type() or "application/octet-stream"
                    return payload, ctype, filename
                curr_idx += 1
        return None, "", ""
    except Exception:
        return None, "", ""
    finally:
        if client:
            try:
                client.logout()
            except Exception:
                pass


def set_mail_flags(
    username: str,
    password: str,
    message_id: str,
    folder: str = "INBOX",
    seen: Optional[bool] = None,
    flagged: Optional[bool] = None,
) -> Dict[str, Any]:
    """Updates seen or flagged status for a message."""
    client = None
    try:
        client = create_imap_client(username, password, timeout=8)
        client.select(f'"{folder}"', readonly=False)

        if seen is not None:
            op = "+FLAGS" if seen else "-FLAGS"
            client.store(str(message_id), op, "\\Seen")

        if flagged is not None:
            op = "+FLAGS" if flagged else "-FLAGS"
            client.store(str(message_id), op, "\\Flagged")

        return {"ok": True, "message_id": message_id}
    except Exception as e:
        return {"ok": False, "error": str(e)}
    finally:
        if client:
            try:
                client.logout()
            except Exception:
                pass


def format_file_size(size_bytes: int) -> str:
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    else:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
