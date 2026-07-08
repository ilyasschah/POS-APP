using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.PromotionCommands.Add
{
    public class CreatePromotionCommand : IRequest<PromotionDto>
    {
        public int CompanyId { get; set; }
        public CreatePromotionRequest Request { get; set; }

        public CreatePromotionCommand(int companyId, CreatePromotionRequest request)
        {
            CompanyId = companyId;
            Request = request;
        }

        public class CreatePromotionCommandHandler : IRequestHandler<CreatePromotionCommand, PromotionDto>
        {
            private readonly PromotionService _service;
            public CreatePromotionCommandHandler(PromotionService service) => _service = service;

            public async Task<PromotionDto> Handle(CreatePromotionCommand command, CancellationToken cancellationToken)
            {
                return await _service.Create(command.CompanyId, command.Request);
            }
        }
    }
}