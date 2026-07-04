import { useEffect, useState } from 'react';
import { Sheet, SheetContent, SheetFooter, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { toast } from 'sonner';
import { gql, useMutation } from '@apollo/client';

const UPDATE_COVER_STYLE = gql`
  mutation UpdateCoverStyle($input: UpdateCoverStyleInput!) {
    updateCoverStyle(input: $input) {
      style {
        id
        name
        value
        tags {
          id
          name
        }
      }
      errors
    }
  }
`;

interface TagType {
  id: string | null;
  name: string;
}

interface StyleType {
  id: string;
  tags: TagType[];
  value: string;
  name: string;
}

export default function EditCoverStyleSheet({
  open,
  onOpenChange,
  style,
  availableTags,
  onUpdated,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  style: StyleType;
  availableTags: { id: string; name: string }[];
  onUpdated: () => void;
}) {
  const [tagSearch, setTagSearch] = useState('');
  const [tags, setTags] = useState<TagType[]>([]);
  const [updateCoverStyle] = useMutation(UPDATE_COVER_STYLE);

  useEffect(() => {
    if (style?.tags) {
      setTags(style.tags);
    }
  }, [style]);

  const handleToggleTag = (tag: TagType) => {
    if (tags.some(t => t.name === tag.name)) {
      setTags(tags.filter(t => t.name !== tag.name));
    } else {
      setTags([...tags, tag]);
    }
  };

  const handleSubmitTags = async () => {
    const tagNames = tags.map(t => t.name);
    const { data } = await updateCoverStyle({
      variables: {
        input: {
          id: style.id,
          tagNames,
        },
      },
    });

    if (data.updateCoverStyle.errors.length === 0) {
      toast.success('Style updated successfully');
      onUpdated();
      onOpenChange(false);
    } else {
      toast.error('Error updating style');
    }
  };

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:w-[500px] p-6">
        <SheetHeader>
          <SheetTitle>Edit Cover Style Tags</SheetTitle>
        </SheetHeader>

        {style && (
          <img
            src={style.value}
            alt="Selected cover"
            className="rounded-md object-cover w-full h-40 mb-4"
          />
        )}

        <div className="space-y-3">
          <Input
            placeholder="Search or add tag..."
            value={tagSearch}
            onChange={e => setTagSearch(e.target.value)}
          />

          <div className="flex flex-wrap gap-2">
            {tags.map(tag => (
              <Badge
                key={tag.id || tag.name}
                variant="secondary"
                className="cursor-pointer"
                onClick={() => handleToggleTag(tag)}
              >
                {tag.name} ✕
              </Badge>
            ))}
          </div>

          <div className="text-sm text-muted-foreground">
            {tagSearch &&
              availableTags
                .filter(tag => tag.name.toLowerCase().includes(tagSearch.toLowerCase()))
                .map(tag => (
                  <div
                    key={tag.id}
                    className="cursor-pointer px-2 py-1 hover:bg-gray-100 rounded"
                    onClick={() => handleToggleTag(tag)}
                  >
                    {tag.name}
                  </div>
                ))}

            {tagSearch &&
              !availableTags.some(t => t.name.toLowerCase() === tagSearch.toLowerCase()) && (
                <div
                  className="cursor-pointer px-2 py-1 hover:bg-gray-100 rounded text-blue-600"
                  onClick={() => {
                    const newTag = { id: null, name: tagSearch.toLowerCase() } as TagType;
                    if (!tags.some(t => t.name === newTag.name)) {
                      setTags([...tags, newTag]);
                    }
                    setTagSearch('');
                  }}
                >
                  Create new tag {`"${tagSearch}"`}
                </div>
              )}
          </div>
        </div>

        <SheetFooter className="mt-6 flex justify-end gap-3">
          <Button disabled={tags.length === 0} onClick={handleSubmitTags}>
            Submit
          </Button>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  );
}
