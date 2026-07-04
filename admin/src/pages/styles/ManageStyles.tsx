import { useQuery, gql, useMutation } from '@apollo/client';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
} from '@/components/ui/dropdown-menu';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import { Settings, Tags, Trash2 } from 'lucide-react';
import { toast, Toaster } from 'sonner';
import withAuth from '@/lib/with-auth';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import { Tag, Style } from '@/types/app';
import CreateCoverStyleSheet from './CreateCoverStyleSheet';
import EditCoverStyleSheet from './EditCoverStyleSheet';
import { ImagePlus } from 'lucide-react';

const GET_STYLES = gql`
  query GetStyles($tag: String) {
    coverStyles: styles(kind: "cover", tag: $tag, limit: 9) {
      id
      name
      value
      tags {
        id
        name
      }
    }
  }
`;

const GET_TAGS = gql`
  query GetTags {
    tags {
      id
      name
    }
  }
`;

const ARCHIVE_COVER_STYLE = gql`
  mutation ArchiveCoverStyle($input: ArchiveCoverStyleInput!) {
    archiveCoverStyle(input: $input) {
      success
      errors
    }
  }
`;

const ManageStyles: React.FC = () => {
  const [selectedStyle, setSelectedStyle] = useState<Style | null>(null);
  const [showEditSheet, setShowEditSheet] = useState(false);
  const [showCreateSheet, setShowCreateSheet] = useState(false);
  const [showArchiveDialog, setShowArchiveDialog] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [searchInput, setSearchInput] = useState('');

  const {
    data: stylesData,
    loading: stylesLoading,
    error: stylesError,
    refetch: refetchStyles,
  } = useQuery(GET_STYLES, { variables: { tag: searchTerm } });
  const styles = stylesData?.coverStyles || [];

  const { data: tagsData } = useQuery(GET_TAGS);
  const availableTags = tagsData?.tags || [];

  const [archiveCoverStyle] = useMutation(ARCHIVE_COVER_STYLE);

  const handleArchive = async () => {
    if (!selectedStyle) return;
    const { data } = await archiveCoverStyle({
      variables: { input: { id: selectedStyle.id } },
    });

    if (data.archiveCoverStyle.success) {
      toast.success('Style archived successfully');
      setShowArchiveDialog(false);
      refetchStyles();
    } else {
      toast.error('Failed to archive style');
    }
  };

  if (stylesLoading) return <LoadingScreen />;
  if (stylesError) return <ErrorScreen details={stylesError.message} />;

  return (
    <div className="space-y-6 px-4 max-w-7xl mx-auto w-full">
      <Toaster />
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-black">Manage Cover Styles</h2>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button className="!bg-black !text-white hover:bg-gray-900">+ Create New Style</Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent side="bottom" align="end" className="z-50 w-48">
            <DropdownMenuItem onClick={() => setShowCreateSheet(true)} className="px-4 py-2">
              <ImagePlus className="w-4 h-4 mr-2" />
              Cover Style
            </DropdownMenuItem>
            <DropdownMenuItem onClick={() => console.log('pending')} className="px-4 py-2">
              <ImagePlus className="w-4 h-4 mr-2" />
              Other Styles
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      <div className="flex items-center gap-3 mb-4">
        <Input
          placeholder="Search by tag..."
          value={searchInput}
          onChange={e => setSearchInput(e.target.value)}
          className="bg-white w-full max-w-md"
        />
        <Button className="!bg-black !text-white" onClick={() => setSearchTerm(searchInput)}>
          Search
        </Button>
        <Button
          variant="ghost"
          onClick={() => {
            setSearchInput('');
            setSearchTerm('');
          }}
        >
          Reset
        </Button>
      </div>

      <div className="w-full mx-auto grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-4 2xl:grid-cols-6 gap-6">
        {styles.map((style: Style) => (
          <div key={style.id} className="border rounded-lg p-3 bg-white shadow-sm space-y-2">
            <img src={style.value} alt="cover" className="rounded-md object-cover w-full h-40" />
            <div className="flex flex-wrap gap-2">
              {style.tags.map((tag: Tag) => (
                <Badge key={tag.id} variant="outline">
                  {tag.name}
                </Badge>
              ))}
            </div>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button size="icon" variant="ghost">
                  <Settings className="w-5 h-5 text-gray-600" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent sideOffset={4} className="z-50 w-48 text-sm">
                <DropdownMenuItem
                  onClick={() => {
                    setSelectedStyle(style);
                    setShowEditSheet(true);
                  }}
                  className="px-4 py-3"
                >
                  <Tags className="w-5 h-5 mr-3" />
                  Edit Tags
                </DropdownMenuItem>
                <DropdownMenuItem
                  className="text-red-500 px-4 py-3"
                  onClick={() => {
                    setSelectedStyle(style);
                    setShowArchiveDialog(true);
                  }}
                >
                  <Trash2 className="w-5 h-5 mr-3" />
                  Archive
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        ))}
      </div>

      <CreateCoverStyleSheet
        open={showCreateSheet}
        onOpenChange={setShowCreateSheet}
        availableTags={availableTags}
        refetchStyles={refetchStyles}
      />

      {selectedStyle && (
        <EditCoverStyleSheet
          open={showEditSheet}
          onOpenChange={open => {
            if (!open) setSelectedStyle(null);
            setShowEditSheet(open);
          }}
          onUpdated={() => {
            refetchStyles();
            setSelectedStyle(null);
          }}
          style={selectedStyle}
          availableTags={availableTags}
        />
      )}

      {/* archive style dialog */}
      <Dialog open={showArchiveDialog} onOpenChange={setShowArchiveDialog}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Confirm Archive</DialogTitle>
          </DialogHeader>
          {selectedStyle && (
            <img
              src={selectedStyle.value}
              alt="Cover to archive"
              className="rounded-md object-cover w-full h-40 mb-4"
            />
          )}
          <p className="text-sm text-muted-foreground mb-4">
            If a style is archived, it can no longer be selected by customers. Existing cards using
            this style will not be affected.
          </p>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setShowArchiveDialog(false)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleArchive}>
              Confirm Archive
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default withAuth(ManageStyles);
