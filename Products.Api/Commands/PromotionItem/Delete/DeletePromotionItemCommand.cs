using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.PromotionItem.Delete
{
    public class DeletePromotionItemCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeletePromotionItemCommand(int id)
        {
            Id = id;
        }

        public class DeletePromotionItemCommandHandler : IRequestHandler<DeletePromotionItemCommand, bool>
        {
            private readonly PromotionItemService _service;

            public DeletePromotionItemCommandHandler(PromotionItemService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeletePromotionItemCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}