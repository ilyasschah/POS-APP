using MediatR;
using System.Threading;
using System.Threading.Tasks;
using Api.Services;

namespace Api.Commands.Promotion.Delete
{
    public class DeletePromotionCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeletePromotionCommand(int id)
        {
            Id = id;
        }

        public class DeletePromotionCommandHandler : IRequestHandler<DeletePromotionCommand, bool>
        {
            private readonly PromotionService _service;

            public DeletePromotionCommandHandler(PromotionService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeletePromotionCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}