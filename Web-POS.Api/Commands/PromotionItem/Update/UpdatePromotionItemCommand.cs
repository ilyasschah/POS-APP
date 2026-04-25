using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.PromotionItemCommands
{
    public class UpdatePromotionItemCommand : IRequest<bool>
    {
        public int CompanyId { get; set; }
        public UpdatePromotionItemRequest Request { get; set; }

        public UpdatePromotionItemCommand(int companyId, UpdatePromotionItemRequest request)
        {
            CompanyId = companyId;
            Request = request;
        }

        public class UpdatePromotionItemCommandHandler : IRequestHandler<UpdatePromotionItemCommand, bool>
        {
            private readonly PromotionItemService _service;
            public UpdatePromotionItemCommandHandler(PromotionItemService service) => _service = service;

            public async Task<bool> Handle(UpdatePromotionItemCommand command, CancellationToken cancellationToken)
            {
                return await _service.Update(command.CompanyId, command.Request);
            }
        }
    }
}