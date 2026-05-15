import { z } from "zod";
import { ZoteroApiInterface, isZoteroApiError } from "../types/zotero-types.js";
import { formatErrorResponse } from "../utils/error-formatter.js";
import { logger } from "../utils/logger.js";

export const toolConfig = {
  name: "add_item_note",
  description: `Attach a note (annotation) to an existing Zotero item. Notes are child items with itemType "note" that appear under their parent in the Zotero UI. Notes support plain text and HTML content — use this to attach paper summaries, researcher annotations, or any textual commentary to library items.

INPUT NOTES:
- Note content can be plain text or HTML (e.g. "<p><b>Key finding:</b> ...</p>")
- The parent item must exist — use search_library or get_items_details to find item keys
- Tags are optional and apply to the note itself, not the parent item
- To retrieve note content later, use get_items_details with the returned note_key`,
  inputSchema: {
    parent_item: z.string().describe("Zotero item key of the parent item to attach the note to"),
    note: z.string().min(1).describe("Note content — plain text or HTML. Must not be empty."),
    tags: z.array(z.string()).optional().describe("Tags to apply to the note"),
  },
} as const;

const AddItemNoteSchema = z.object(toolConfig.inputSchema);

export async function handleAddItemNote(
  zoteroApi: ZoteroApiInterface,
  userId: string,
  args: Record<string, unknown>
): Promise<{ content: Array<{ type: "text"; text: string }> }> {
  const { parent_item, note, tags } = AddItemNoteSchema.parse(args);

  const itemData: Record<string, unknown> = {
    itemType: "note",
    note,
    parentItem: parent_item,
    tags: (tags ?? []).map((t) => ({ tag: t })),
  };

  try {
    const response = await zoteroApi
      .library("user", userId)
      .items()
      .post([itemData]);

    if (!response.isSuccess()) {
      const errors = response.getErrors();
      const errorMsg = Object.values(errors).join("; ") || "Unknown error";
      return formatErrorResponse("Failed to create note", {
        parent_item,
        details: errorMsg,
      });
    }

    const created = response.getData();
    const item = created[0];

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            { note_key: item.key, parent_item, note_length: note.length, tags: tags ?? [] },
            null, 2
          ),
        },
      ],
    };
  } catch (err) {
    if (isZoteroApiError(err)) {
      logger.error("Tool execution failed", {
        tool: "add_item_note",
        status: err.response?.status,
        errorMessage: err.message,
        url: err.response?.url,
      });
    }
    throw err;
  }
}