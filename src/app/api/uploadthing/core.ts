import { createUploadthing, type FileRouter } from "uploadthing/next";

const f = createUploadthing();

export const ourFileRouter = {
  reportImage: f({
    image: {
      maxFileSize: "4MB",
      maxFileCount: 1,
    },
  }).onUploadComplete(async () => {
    return { uploaded: true };
  }),
} satisfies FileRouter;

export type OurFileRouter = typeof ourFileRouter;
