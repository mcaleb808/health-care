import { auth } from "@clerk/nextjs/server";
import OpenAI from "openai";

const systemPrompt = `
You are provided with notes written by a doctor from a patient's visit.
Your job is to summarize the visit for the doctor and provide an email.
Reply with exactly three sections with the headings:
### Summary of visit for the doctor's records
### Next steps for the doctor
### Draft of email to patient in patient-friendly language
`;

function userPromptFor(
  patientName: string,
  dateOfVisit: string,
  notes: string
): string {
  return `Create the summary, next steps and draft email for:
Patient Name: ${patientName}
Date of Visit: ${dateOfVisit}
Notes:
${notes}`;
}

export async function POST(request: Request) {
  const { userId } = await auth();
  if (!userId) {
    return new Response("Unauthorized", { status: 401 });
  }

  const body = await request.json();
  const { patient_name, date_of_visit, notes } = body;

  if (!patient_name || !date_of_visit || !notes) {
    return new Response("Missing required fields", { status: 400 });
  }

  const client = new OpenAI();
  const stream = await client.chat.completions.create({
    model: "gpt-4.1-nano",
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userPromptFor(patient_name, date_of_visit, notes) },
    ],
    stream: true,
  });

  const encoder = new TextEncoder();
  const readable = new ReadableStream({
    async start(controller) {
      for await (const chunk of stream) {
        const text = chunk.choices[0]?.delta?.content;
        if (text) {
          const lines = text.split("\n");
          for (let i = 0; i < lines.length - 1; i++) {
            controller.enqueue(encoder.encode(`data: ${lines[i]}\n\n`));
            controller.enqueue(encoder.encode("data:  \n"));
          }
          controller.enqueue(
            encoder.encode(`data: ${lines[lines.length - 1]}\n\n`)
          );
        }
      }
      controller.close();
    },
  });

  return new Response(readable, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  });
}
