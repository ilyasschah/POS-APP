using MediatR;
using Api.Services;

namespace Api.Commands.PromotionItem.Delete
{
    public class DeletePromotionItemCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public DeletePromotionItemCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeletePromotionItemCommandHandler : IRequestHandler<DeletePromotionItemCommand, bool>
        {
            private readonly PromotionItemService _service;
            public DeletePromotionItemCommandHandler(PromotionItemService service) => _service = service;

            public async Task<bool> Handle(DeletePromotionItemCommand command, CancellationToken cancellationToken)
            {
                return await _service.Delete(command.Id, command.CompanyId);
            }
        }
    }
}